using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Облачко рассыпанной пыльцы. Разлетается, зависает в воздухе на высоте
    /// полёта пчелы и через 25 секунд исчезает. Пролетел сквозь — подобрал.
    /// </summary>
    public class PollenPickup : MonoBehaviour
    {
        const float Lifetime = 25f;
        const float PickupDelay = 0.7f;
        const float FloatHeight = 1.8f;

        int _value;
        bool _fromWasp;
        float _bornAt;
        Vector3 _velocity;
        float _phase;

        public static void Scatter(Vector3 from, int total, bool fromWasp)
        {
            if (total <= 0) return;
            var world = GameFlow.I != null ? GameFlow.I.World : null;
            Transform parent = world != null ? world.Dynamic : null;

            int pieces = Mathf.Clamp(total, 1, 6);
            for (int i = 0; i < pieces; i++)
            {
                int value = total / pieces + (i < total % pieces ? 1 : 0);
                if (value <= 0) continue;

                var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                go.name = "Пыльца";
                if (parent != null) go.transform.SetParent(parent, false);
                go.transform.position = from;
                go.transform.localScale = Vector3.one * (0.22f + 0.03f * Mathf.Min(value, 6));
                go.GetComponent<Renderer>().sharedMaterial = Shape.Mat(Palette.Gold, 0.6f);

                var col = go.GetComponent<SphereCollider>();
                col.isTrigger = true;
                col.radius = 0.75f / go.transform.localScale.x; // ~0.75 м в мире

                var p = go.AddComponent<PollenPickup>();
                p._value = value;
                p._fromWasp = fromWasp;
                p._bornAt = Time.time;
                p._phase = Random.value * 10f;
                Vector2 dir = Random.insideUnitCircle.normalized;
                p._velocity = new Vector3(dir.x, 0.6f, dir.y) * Random.Range(3f, 5.5f);
            }
        }

        void Update()
        {
            if (Time.time - _bornAt > Lifetime)
            {
                Destroy(gameObject);
                return;
            }

            _velocity = Vector3.MoveTowards(_velocity, Vector3.zero, 6f * Time.deltaTime);
            Vector3 pos = transform.position + _velocity * Time.deltaTime;
            float targetY = FloatHeight + Mathf.Sin(Time.time * 2f + _phase) * 0.15f;
            pos.y = Mathf.Lerp(pos.y, targetY, 2f * Time.deltaTime);
            transform.position = pos;

            // Мигает перед исчезновением
            float left = Lifetime - (Time.time - _bornAt);
            var r = GetComponent<Renderer>();
            if (r != null) r.enabled = left > 4f || Mathf.Repeat(Time.time * 6f, 1f) > 0.35f;
        }

        void OnTriggerStay(Collider other)
        {
            if (Time.time - _bornAt < PickupDelay) return;
            var bee = other.GetComponentInParent<BeeController>();
            if (bee == null || bee.Pollen >= bee.Capacity) return;

            int add = Mathf.Min(_value, bee.Capacity - bee.Pollen);
            bee.AddPollen(add, false);
            _value -= add;

            var stats = GameFlow.I != null ? GameFlow.I.Stats : null;
            if (stats != null)
            {
                if (_fromWasp) stats.pollenStolen = Mathf.Max(0, stats.pollenStolen - add);
                else stats.pollenLost = Mathf.Max(0, stats.pollenLost - add);
            }

            if (_value <= 0) Destroy(gameObject);
        }
    }
}
