using UnityEngine;

namespace Phelki
{
    /// <summary>Машет крыльями (для пчёл роя и ос).</summary>
    public class WingFlap : MonoBehaviour
    {
        public float speed = 50f;
        Transform[] _wings;

        void Start() => _wings = BeeVisual.FindWings(transform);

        void Update()
        {
            if (_wings == null) return;
            float flap = Mathf.Sin(Time.time * speed) * 50f;
            foreach (var w in _wings)
            {
                float side = w.localPosition.x >= 0f ? 1f : -1f;
                w.localEulerAngles = new Vector3(0f, side * -15f, side * flap);
            }
        }
    }
}
