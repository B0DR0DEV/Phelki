using UnityEngine;

namespace Phelki
{
    /// <summary>Покачивание (простыни на верёвке).</summary>
    public class Sway : MonoBehaviour
    {
        public float angle = 6f;
        public float speed = 1.3f;
        float _phase;
        Quaternion _base;

        void Start()
        {
            _base = transform.localRotation;
            _phase = Random.value * 10f;
        }

        void Update() =>
            transform.localRotation = _base * Quaternion.Euler(Mathf.Sin(Time.time * speed + _phase) * angle, 0f, 0f);
    }
}
