using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Оса-гопник. Трётся у мусорки. Видит пчелу с пыльцой рядом — гонится
    /// и отжимает до 5 пыльцы. Если пчела врезалась в неё рывком — оса
    /// оглушена на 3 секунды и роняет всё, что отжала.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class Wasp : MonoBehaviour
    {
        public float chaseSpeed = 6.2f;
        public float aggroRadius = 9f;
        public int stealAmount = 5;

        Rigidbody _rb;
        Transform _visual;
        Vector3 _home;
        int _carried;
        float _stunUntil, _cooldownUntil, _seed, _yaw;

        public bool IsStunned => Time.time < _stunUntil;

        public static Wasp Spawn(Transform parent, Vector3 home)
        {
            var go = new GameObject("Оса");
            go.transform.SetParent(parent, false);
            go.transform.position = home;

            var rb = go.AddComponent<Rigidbody>();
            var col = go.AddComponent<SphereCollider>();
            col.radius = 0.32f;

            var visual = Shape.Node("Вид", go.transform, Vector3.zero);
            visual.localScale = Vector3.one * 0.85f;
            var art = PhelkiArtSet.Current;
            if (art != null && art.wasp != null) Shape.PlaceModel(art.wasp, visual, Vector3.zero, 0f, false);
            else BeeVisual.BuildPlaceholder(visual, true);
            visual.gameObject.AddComponent<WingFlap>().speed = 60f;

            var w = go.AddComponent<Wasp>();
            w._rb = rb;
            w._visual = visual;
            w._home = home;
            w._seed = Random.value * 100f;
            return w;
        }

        void Awake()
        {
            _rb = GetComponent<Rigidbody>();
            _rb.useGravity = false;
            _rb.mass = 0.6f;
            _rb.interpolation = RigidbodyInterpolation.Interpolate;
            _rb.constraints = RigidbodyConstraints.FreezeRotation;
        }

        public void ResetToHome()
        {
            transform.position = _home;
            _rb.SetVel(Vector3.zero);
            _carried = 0;
            _stunUntil = 0f;
            _cooldownUntil = 0f;
            _rb.useGravity = false;
        }

        void FixedUpdate()
        {
            if (IsStunned)
            {
                _rb.useGravity = true;
                return;
            }
            _rb.useGravity = false;

            var flow = GameFlow.I;
            var bee = flow != null && flow.Current == GameFlow.State.Sortie ? flow.Bee : null;

            bool chase = bee != null && bee.Pollen > 0 && Time.time > _cooldownUntil && _carried < 15 &&
                         Vector3.Distance(bee.transform.position, _home) < aggroRadius;

            Vector3 target = chase
                ? bee.transform.position
                : _home + new Vector3(Mathf.Sin(Time.time * 0.9f + _seed) * 1.6f,
                    Mathf.Sin(Time.time * 1.7f + _seed) * 0.3f,
                    Mathf.Cos(Time.time * 0.7f + _seed) * 1.6f);

            Vector3 desired = Vector3.ClampMagnitude((target - transform.position) * 2f, chase ? chaseSpeed : 3f);
            _rb.SetVel(Vector3.MoveTowards(_rb.Vel(), desired, 20f * Time.fixedDeltaTime));
        }

        void LateUpdate()
        {
            if (_visual == null) return;
            Vector3 v = _rb.Vel();
            v.y = 0f;
            if (v.sqrMagnitude > 0.2f) _yaw = Mathf.LerpAngle(_yaw, Mathf.Atan2(v.x, v.z) * Mathf.Rad2Deg, 8f * Time.deltaTime);
            float wobble = IsStunned ? Mathf.Sin(Time.time * 20f) * 40f : 0f;
            _visual.rotation = Quaternion.Euler(IsStunned ? 160f : 10f, _yaw, wobble);
        }

        void OnCollisionEnter(Collision c)
        {
            var bee = c.collider.GetComponentInParent<BeeController>();
            if (bee == null) return;
            var flow = GameFlow.I;
            if (flow == null || flow.Current != GameFlow.State.Sortie) return;

            if (bee.IsDashing)
            {
                Stun(bee.Velocity);
                return;
            }
            if (IsStunned || Time.time < _cooldownUntil) return;

            int stolen = bee.LosePollen(stealAmount);
            if (stolen > 0)
            {
                _carried += stolen;
                flow.Stats.pollenStolen += stolen;
                flow.Say(Lines.Pick(Lines.WaspSteal));
                flow.Toast($"Осы отжали {stolen} пыльцы");
            }
            Vector3 away = bee.transform.position - transform.position;
            away.y = 0f;
            bee.Knock(away.normalized * 9f);
            _cooldownUntil = Time.time + 3f;
        }

        void Stun(Vector3 hitVelocity)
        {
            var flow = GameFlow.I;
            _stunUntil = Time.time + 3f;
            _cooldownUntil = _stunUntil + 1f;
            _rb.SetVel(hitVelocity * 0.6f + Vector3.up * 2f);

            if (flow != null)
            {
                flow.Stats.waspsRammed++;
                flow.Say(Lines.Pick(Lines.WaspStun));
            }
            if (_carried > 0)
            {
                PollenPickup.Scatter(transform.position, _carried, true);
                _carried = 0;
            }
        }
    }
}
