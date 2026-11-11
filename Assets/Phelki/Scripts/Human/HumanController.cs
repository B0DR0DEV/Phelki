using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Человек-дачник («неуважающий»). Управление тем же одним пальцем:
    /// ведёшь — бежит к пальцу; быстрый свайп — перекат (на время переката не жалят).
    /// Кнопки: мухобойка (сбивает пчёл рядом) и дымарь (усыпляет пчёл вокруг).
    /// Каждый укус раздувает лицо и руки и замедляет. Отёк 100% — скорая.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class HumanController : MonoBehaviour
    {
        public const float SwatCooldown = 0.8f;
        public const float SmokeCooldown = 10f;
        public const float SwatRange = 2.3f;
        public const float SmokeRadius = 4f;
        public const float StingSwelling = 0.09f;

        public float runSpeed = 5.4f;
        public float acceleration = 32f;
        public float dodgeSpeed = 12f;
        public float dodgeDuration = 0.32f;
        public float dodgeCooldown = 1.3f;

        public float Swelling { get; private set; }
        public bool IsDodging => Time.time < _dodgeUntil;
        public bool Frozen { get; set; }
        public bool Invulnerable => IsDodging || Frozen;
        public float Facing { get; private set; }
        public Vector3 Velocity => _rb != null ? _rb.Vel() : Vector3.zero;
        public float SwatReadyIn => Mathf.Max(0f, _swatReadyAt - Time.time);
        public float SmokeReadyIn => Mathf.Max(0f, _smokeReadyAt - Time.time);
        public Collider Body { get; private set; }

        Rigidbody _rb;
        Camera _cam;
        HumanVisual _visual;
        readonly FingerTracker _finger = new FingerTracker();
        float _dodgeUntil, _dodgeReadyAt, _swatReadyAt, _smokeReadyAt, _stingGrace;
        Vector3 _dodgeDir;

        static EscapeMatch Match => GameFlow.I != null ? GameFlow.I.Escape : null;

        public static HumanController Spawn(Transform parent, Vector3 position, float yaw)
        {
            var go = new GameObject("Дачник");
            go.transform.SetParent(parent, false);
            go.transform.position = position;

            go.AddComponent<Rigidbody>();
            var col = go.AddComponent<CapsuleCollider>();
            col.center = new Vector3(0f, 1f, 0f);
            col.height = 2f;
            col.radius = 0.38f;

            var h = go.AddComponent<HumanController>();
            h.Body = col;
            h.Facing = yaw;

            var visualRoot = Shape.Node("Вид", go.transform, Vector3.zero);
            h._visual = visualRoot.gameObject.AddComponent<HumanVisual>();
            h._visual.Build(h);
            return h;
        }

        void Awake()
        {
            _rb = GetComponent<Rigidbody>();
            _rb.mass = 70f;
            _rb.useGravity = true;
            _rb.SetDamping(0f, 5f);
            _rb.interpolation = RigidbodyInterpolation.Interpolate;
            _rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            _rb.constraints = RigidbodyConstraints.FreezeRotation;
            _cam = Camera.main;
        }

        void Update()
        {
            bool active = !Frozen && GameFlow.I != null && GameFlow.I.Current == GameFlow.State.Escape;
            Vector2 swipe = _finger.Update(active);
            if (swipe != Vector2.zero && Time.time >= _dodgeReadyAt) Dodge(swipe);
        }

        void FixedUpdate()
        {
            Vector3 v = _rb.Vel();
            Vector3 horiz = new Vector3(v.x, 0f, v.z);
            float cap = runSpeed * (1f - 0.4f * Swelling);

            if (Frozen)
            {
                horiz = Vector3.MoveTowards(horiz, Vector3.zero, acceleration * Time.fixedDeltaTime);
            }
            else if (IsDodging)
            {
                horiz = _dodgeDir * dodgeSpeed;
            }
            else if (_finger.Pressed && FingerTracker.ToPlane(Cam, _finger.Position, transform.position.y, out var target))
            {
                Vector3 to = target - transform.position;
                to.y = 0f;
                float dist = to.magnitude;
                Vector3 desired = dist > 0.3f ? to / dist * Mathf.Min(cap, dist * 3f) : Vector3.zero;
                horiz = Vector3.MoveTowards(horiz, desired, acceleration * Time.fixedDeltaTime);
            }
            else
            {
                horiz = Vector3.MoveTowards(horiz, Vector3.zero, acceleration * 0.6f * Time.fixedDeltaTime);
            }

            if (horiz.sqrMagnitude > 0.5f) Facing = Mathf.Atan2(horiz.x, horiz.z) * Mathf.Rad2Deg;
            _rb.SetVel(new Vector3(horiz.x, v.y, horiz.z));
        }

        Camera Cam
        {
            get
            {
                if (_cam == null) _cam = Camera.main;
                return _cam;
            }
        }

        void Dodge(Vector2 screenDir)
        {
            Vector3 dir = FingerTracker.ScreenDirToWorld(Cam, screenDir);
            if (dir == Vector3.zero) return;
            _dodgeDir = dir;
            _dodgeUntil = Time.time + dodgeDuration;
            _dodgeReadyAt = Time.time + dodgeCooldown;
            Facing = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
            if (_visual != null) _visual.Roll(dodgeDuration);
            var m = Match;
            if (m != null) m.Stats.dodges++;
        }

        // ── Инструменты ────────────────────────────────────────

        public void Swat()
        {
            var m = Match;
            if (Frozen || m == null || Time.time < _swatReadyAt) return;
            _swatReadyAt = Time.time + SwatCooldown;
            if (_visual != null) _visual.Swing();

            Vector3 fwd = Quaternion.Euler(0f, Facing, 0f) * Vector3.forward;
            Vector3 chest = transform.position + Vector3.up * 1.3f;
            int hits = 0;
            foreach (var bot in m.Bots)
            {
                if (bot == null || bot.Disabled) continue;
                Vector3 d = bot.transform.position - chest;
                float dist = d.magnitude;
                if (dist > SwatRange) continue;
                Vector3 flat = new Vector3(d.x, 0f, d.z);
                bool inFront = dist < 1.1f || Vector3.Angle(fwd, flat) < 75f;
                if (!inFront) continue;

                bot.Stun(3f, flat.normalized * 7f + Vector3.up * 2f);
                hits++;
                if (hits >= 4) break;
            }

            if (hits > 0)
            {
                m.Stats.swats += hits;
                GameFlow.I.Toast(hits == 1 ? "Шлёп!" : $"Шлёп ×{hits}!");
                if (Random.value < 0.35f) GameFlow.I.Say(Lines.Pick(Lines.Swat));
            }
        }

        public void Smoke()
        {
            var m = Match;
            if (Frozen || m == null || Time.time < _smokeReadyAt) return;
            _smokeReadyAt = Time.time + SmokeCooldown;

            SmokeCloud.Spawn(transform.position + Vector3.up * 1.2f, m.transform);
            int slept = 0;
            foreach (var bot in m.Bots)
            {
                if (bot == null) continue;
                if ((bot.transform.position - transform.position).magnitude > SmokeRadius) continue;
                bot.Sleep(3.5f);
                slept++;
            }
            m.Stats.smokes++;
            GameFlow.I.Toast(slept > 0 ? $"Дым! Уснули: {slept}" : "Дым!");
            GameFlow.I.Say(Lines.Pick(Lines.SmokeUsed));
        }

        /// <summary>Пчела пытается ужалить. Возвращает true, если укус прошёл.</summary>
        public bool TrySting()
        {
            if (Invulnerable || Time.time < _stingGrace) return false;
            _stingGrace = Time.time + 0.25f;
            Swelling = Mathf.Min(1f, Swelling + StingSwelling);

            var m = Match;
            if (m != null) m.OnStung(this);
            if (_visual != null) _visual.Flinch();
            if (GameFlow.I != null && GameFlow.I.Cam != null) GameFlow.I.Cam.Shake(0.25f);
            return true;
        }
    }
}
