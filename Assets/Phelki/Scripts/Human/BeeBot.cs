using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Пчела-бот в режиме побега. Окружает дачника со своей стороны,
    /// жалит и отлетает. Мухобойкой её можно сбить (3 с), дымом — усыпить.
    /// Позже её место займёт живой игрок-пчела (часть 3, онлайн).
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class BeeBot : MonoBehaviour
    {
        public float speed = 5.9f;
        public float stingCooldown = 1.8f;

        Rigidbody _rb;
        Transform _visual;
        float _angle, _height, _yaw;
        float _stunUntil, _sleepUntil, _retreatUntil, _nextSting, _wakeAt;

        public bool Stunned => Time.time < _stunUntil;
        public bool Asleep => Time.time < _sleepUntil;
        public bool Disabled => Stunned || Asleep;
        public Collider Body { get; private set; }

        public static BeeBot Spawn(Transform parent, Vector3 position, float angle, float wakeDelay)
        {
            var go = new GameObject("Пчела-бот");
            go.transform.SetParent(parent, false);
            go.transform.position = position;

            go.AddComponent<Rigidbody>();
            var col = go.AddComponent<SphereCollider>();
            col.radius = 0.25f;

            var visual = Shape.Node("Вид", go.transform, Vector3.zero);
            visual.localScale = Vector3.one * 0.6f;
            var art = PhelkiArtSet.Current;
            if (art != null && art.bee != null) Shape.PlaceModel(art.bee, visual, Vector3.zero, 0f, false);
            else BeeVisual.BuildPlaceholder(visual, false);
            visual.gameObject.AddComponent<WingFlap>().speed = Random.Range(50f, 62f);

            var bot = go.AddComponent<BeeBot>();
            bot.Body = col;
            bot._visual = visual;
            bot._angle = angle;
            bot._height = Random.Range(1.1f, 1.7f);
            bot._wakeAt = Time.time + wakeDelay;
            bot.speed *= Random.Range(0.9f, 1.1f);
            return bot;
        }

        void Awake()
        {
            _rb = GetComponent<Rigidbody>();
            _rb.useGravity = false;
            _rb.mass = 0.3f;
            _rb.interpolation = RigidbodyInterpolation.Interpolate;
            _rb.constraints = RigidbodyConstraints.FreezeRotation;
        }

        public void Stun(float seconds, Vector3 push)
        {
            _stunUntil = Time.time + seconds;
            _rb.useGravity = true;
            _rb.SetVel(push);
        }

        public void Sleep(float seconds)
        {
            _sleepUntil = Mathf.Max(_sleepUntil, Time.time + seconds);
        }

        void FixedUpdate()
        {
            float dt = Time.fixedDeltaTime;
            var match = GameFlow.I != null ? GameFlow.I.Escape : null;
            var human = match != null ? match.Human : null;

            if (Stunned)
            {
                _rb.useGravity = true;
                return;
            }
            _rb.useGravity = false;

            Vector3 pos = transform.position;
            Vector3 v = _rb.Vel();

            if (Asleep)
            {
                // Спит: медленно оседает и дрейфует
                Vector3 drift = new Vector3(0f, pos.y > 0.6f ? -0.6f : 0f, 0f);
                _rb.SetVel(Vector3.MoveTowards(v, drift, 8f * dt));
                return;
            }

            Vector3 goal;
            float spd = speed;
            if (human == null || Time.time < _wakeAt)
            {
                // Ещё не заметила: кружит у улья
                Vector3 home = GameFlow.I != null ? GameFlow.I.World.HivePosition : Vector3.zero;
                float a = Time.time * 0.8f + _angle * Mathf.Deg2Rad;
                goal = home + new Vector3(Mathf.Cos(a) * 2.5f, 2f, Mathf.Sin(a) * 2.5f);
                spd = 3f;
            }
            else
            {
                Vector3 target = human.transform.position + Vector3.up * _height;
                if (Time.time < _retreatUntil)
                {
                    Vector3 away = pos - target;
                    away.y = 0f;
                    goal = pos + away.normalized * 3f + Vector3.up * 0.6f;
                }
                else
                {
                    // Каждая заходит со своей стороны, точка захода медленно вращается
                    Vector3 side = Quaternion.Euler(0f, _angle + Time.time * 35f, 0f) * Vector3.forward;
                    goal = target + side * 0.45f;

                    // Упреждение: целится чуть вперёд по ходу бега
                    Vector3 hv = human.Velocity;
                    hv.y = 0f;
                    goal += hv * 0.25f;
                }
            }

            Vector3 desired = Vector3.ClampMagnitude((goal - pos) * 2.5f, spd);

            // Расталкиваются, чтобы не слипаться в одну точку
            if (match != null)
            {
                foreach (var other in match.Bots)
                {
                    if (other == null || other == this) continue;
                    Vector3 d = pos - other.transform.position;
                    float sq = d.sqrMagnitude;
                    if (sq < 0.64f && sq > 0.0001f) desired += d / sq * 0.6f;
                }
            }

            _rb.SetVel(Vector3.MoveTowards(v, desired, 18f * dt));

            // Укус
            if (human != null && Time.time >= _wakeAt && Time.time >= _nextSting && Time.time >= _retreatUntil)
            {
                Vector3 chest = human.transform.position + Vector3.up * 1.3f;
                if ((chest - pos).sqrMagnitude < 0.95f * 0.95f && human.TrySting())
                {
                    _nextSting = Time.time + stingCooldown;
                    _retreatUntil = Time.time + 0.9f;
                }
            }
        }

        void LateUpdate()
        {
            if (_visual == null) return;
            Vector3 v = _rb.Vel();
            v.y = 0f;
            if (v.sqrMagnitude > 0.2f)
                _yaw = Mathf.LerpAngle(_yaw, Mathf.Atan2(v.x, v.z) * Mathf.Rad2Deg, 10f * Time.deltaTime);

            float roll = 0f, pitch = 12f;
            if (Stunned)
            {
                pitch = 170f;
                roll = Mathf.Sin(Time.time * 20f) * 30f;
            }
            else if (Asleep)
            {
                pitch = 0f;
                roll = 70f + Mathf.Sin(Time.time * 2f) * 10f;
            }
            _visual.rotation = Quaternion.Euler(pitch, _yaw, roll);
        }
    }
}
