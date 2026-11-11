using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Пчела игрока. Управление одним пальцем:
    /// ведёшь — летит к пальцу; отпустил — зависает и её сносит ветром;
    /// быстрый свайп — рывок (им можно протаранить осу).
    /// Чем больше пыльцы несёт, тем толще и медленнее.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class BeeController : MonoBehaviour
    {
        [Header("Полёт")] public float maxSpeed = 8.5f;
        public float acceleration = 26f;
        public float hoverBrake = 5f;
        public float cruiseHeight = 2.1f;

        [Header("Рывок")] public float dashSpeed = 17f;
        public float dashDuration = 0.32f;
        public float dashCooldown = 0.9f;

        [Header("Пыльца")] public int capacity = 30;
        public float collectPerSecond = 6f;
        public float rareCollectPerSecond = 11f;

        public int Pollen { get; private set; }
        public int Capacity => capacity;
        public float Load => capacity > 0 ? (float)Pollen / capacity : 0f;
        public bool IsDashing => Time.time < _dashUntil;
        public bool IsStuck => Time.time < _stuckUntil;
        public bool IsSteering { get; private set; }
        public Vector3 Velocity => _rb != null ? _rb.Vel() : Vector3.zero;
        public Flower CurrentFlower { get; private set; }
        public Collider Body { get; private set; }

        Rigidbody _rb;
        Camera _cam;
        BeeVisual _visual;

        float _dashUntil, _dashReadyAt, _stuckUntil, _stunUntil, _lastCrash, _collectAcc;
        Vector3 _dashDir, _externalForce;
        Vector2 _pointer;
        bool _fullSaid;
        readonly FingerTracker _finger = new FingerTracker();

        static SortieStats Stats => GameFlow.I != null ? GameFlow.I.Stats : null;

        public static BeeController Spawn(Transform at)
        {
            var go = new GameObject("Пчела");
            go.transform.position = at.position;

            go.AddComponent<Rigidbody>();
            var col = go.AddComponent<SphereCollider>();
            col.radius = 0.38f;
            col.material = Compat.Bouncy(0.55f);

            var bee = go.AddComponent<BeeController>();
            bee.Body = col;

            var visualRoot = Shape.Node("Вид", go.transform, Vector3.zero);
            var art = PhelkiArtSet.Current;
            if (art != null && art.bee != null) Shape.PlaceModel(art.bee, visualRoot, Vector3.zero, 0f, false);
            else BeeVisual.BuildPlaceholder(visualRoot, false);

            bee._visual = visualRoot.gameObject.AddComponent<BeeVisual>();
            bee._visual.Bind(bee);
            return bee;
        }

        void Awake()
        {
            _rb = GetComponent<Rigidbody>();
            _rb.useGravity = false;
            _rb.mass = 1f;
            _rb.SetDamping(0f, 5f);
            _rb.interpolation = RigidbodyInterpolation.Interpolate;
            _rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            _rb.constraints = RigidbodyConstraints.FreezeRotation;
            _cam = Camera.main;
        }

        void Update()
        {
            bool active = GameFlow.I != null && GameFlow.I.Current == GameFlow.State.Sortie;
            Vector2 swipe = _finger.Update(active);
            _pointer = _finger.Position;
            IsSteering = _finger.Pressed && Time.time >= _stunUntil;
            if (swipe != Vector2.zero && Time.time >= _dashReadyAt) Dash(swipe);
        }

        void FixedUpdate()
        {
            float dt = Time.fixedDeltaTime;
            var world = GameFlow.I != null ? GameFlow.I.World : null;

            Vector3 v = _rb.Vel();
            Vector3 horiz = new Vector3(v.x, 0f, v.z);
            float cap = maxSpeed * Mathf.Lerp(1f, 0.62f, Load);
            if (IsStuck) cap *= 0.25f;

            if (IsDashing)
            {
                horiz = _dashDir * dashSpeed;
            }
            else if (IsSteering && TryPointerToPlane(_pointer, out var target))
            {
                Vector3 to = target - transform.position;
                to.y = 0f;
                float dist = to.magnitude;
                Vector3 desired = dist > 0.25f ? to / dist * Mathf.Min(cap, dist * 2.2f) : Vector3.zero;
                horiz = Vector3.MoveTowards(horiz, desired, acceleration * dt);
            }
            else
            {
                horiz = Vector3.MoveTowards(horiz, Vector3.zero, hoverBrake * dt);
            }

            if (world != null) horiz += world.Wind * (IsSteering ? 0.25f : 1f) * dt;
            horiz += _externalForce * dt;
            _externalForce = Vector3.zero;

            if (IsStuck) horiz = Vector3.ClampMagnitude(horiz, cap);
            else if (!IsDashing) horiz = Vector3.ClampMagnitude(horiz, Mathf.Max(cap * 1.8f, 12f));

            // Высота: над цветком, если зависли рядом, — опускаемся к нему.
            float targetY = cruiseHeight;
            CurrentFlower = null;
            if (world != null && !IsDashing && horiz.magnitude < 3.6f)
            {
                var f = world.NearestFlower(transform.position, 1.7f);
                if (f != null)
                {
                    CurrentFlower = f;
                    targetY = f.HeadPos.y + 0.45f;
                }
            }
            float bob = Mathf.Sin(Time.time * 3.1f) * 0.12f;
            float vy = (targetY + bob - transform.position.y) * 4f;

            _rb.SetVel(new Vector3(horiz.x, vy, horiz.z));
            Collect(dt);
        }

        void Collect(float dt)
        {
            if (CurrentFlower == null || Pollen >= capacity)
            {
                _collectAcc = 0f;
                return;
            }
            if ((CurrentFlower.HeadPos - transform.position).magnitude > 1.05f) return;

            _collectAcc += (CurrentFlower.Rare ? rareCollectPerSecond : collectPerSecond) * dt;
            int want = Mathf.FloorToInt(_collectAcc);
            if (want <= 0) return;
            _collectAcc -= want;

            int got = CurrentFlower.Take(Mathf.Min(want, capacity - Pollen));
            if (got > 0) AddPollen(got, true);
        }

        bool TryPointerToPlane(Vector2 screen, out Vector3 point)
        {
            point = default;
            if (_cam == null) _cam = Camera.main;
            if (_cam == null) return false;

            var ray = _cam.ScreenPointToRay(screen);
            var plane = new Plane(Vector3.up, new Vector3(0f, transform.position.y, 0f));
            if (!plane.Raycast(ray, out float enter)) return false;
            point = ray.GetPoint(enter);
            return true;
        }

        void Dash(Vector2 screenDir)
        {
            if (_cam == null) _cam = Camera.main;
            if (_cam == null) return;

            Vector3 right = Vector3.ProjectOnPlane(_cam.transform.right, Vector3.up).normalized;
            Vector3 forward = Vector3.ProjectOnPlane(_cam.transform.forward, Vector3.up).normalized;
            Vector3 dir = right * screenDir.x + forward * screenDir.y;
            if (dir.sqrMagnitude < 0.01f) return;

            _dashDir = dir.normalized;
            _dashUntil = Time.time + dashDuration;
            _dashReadyAt = Time.time + dashCooldown;
            _stuckUntil = 0f;
            if (_visual != null) _visual.Dash();
        }

        // ── Пыльца ─────────────────────────────────────────────

        public void AddPollen(int amount, bool collected)
        {
            int before = Pollen;
            Pollen = Mathf.Clamp(Pollen + amount, 0, capacity);
            int added = Pollen - before;
            var stats = Stats;
            if (collected && stats != null) stats.pollenCollected += added;

            if (Pollen >= capacity && !_fullSaid)
            {
                _fullSaid = true;
                if (GameFlow.I != null) GameFlow.I.Say(Lines.Pick(Lines.Full));
            }
        }

        public int TakeAllPollen()
        {
            int p = Pollen;
            Pollen = 0;
            _fullSaid = false;
            return p;
        }

        public int LosePollen(int amount)
        {
            int lost = Mathf.Min(Mathf.Max(0, amount), Pollen);
            Pollen -= lost;
            if (Pollen < capacity) _fullSaid = false;
            return lost;
        }

        /// <summary>Рассыпать пыльцу облачками — их можно подобрать обратно.</summary>
        public void DropPollen(int amount)
        {
            int lost = LosePollen(amount);
            if (lost <= 0) return;

            var stats = Stats;
            if (stats != null) stats.pollenLost += lost;
            PollenPickup.Scatter(transform.position, lost, false);
        }

        // ── Внешние воздействия ────────────────────────────────

        public void Stick(float seconds)
        {
            _stuckUntil = Time.time + seconds;
            _dashUntil = 0f;
        }

        public void Push(Vector3 force) => _externalForce += force;

        public void Knock(Vector3 velocity, float stunSeconds = 0.35f)
        {
            _dashUntil = 0f;
            _stunUntil = Time.time + stunSeconds;
            _rb.SetVel(velocity);
            if (_visual != null) _visual.Tumble();
        }

        void OnCollisionEnter(Collision c)
        {
            if (c.collider.GetComponentInParent<Wasp>() != null) return;

            float impact = c.relativeVelocity.magnitude;
            if (impact < 6f || Time.time - _lastCrash < 0.7f) return;

            _lastCrash = Time.time;
            _stunUntil = Time.time + 0.45f;
            _dashUntil = 0f;

            var stats = Stats;
            if (stats != null) stats.crashes++;

            int lose = Pollen > 0 ? Mathf.Max(1, Mathf.RoundToInt(Pollen * 0.25f)) : 0;
            DropPollen(lose);

            if (_visual != null) _visual.Tumble();
            if (GameFlow.I != null) GameFlow.I.Say(Lines.Pick(Lines.Crash));
        }
    }
}
