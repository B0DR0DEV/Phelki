using UnityEngine;

namespace Phelki
{
    /// <summary>Облако дыма из дымаря: клубы раздуваются, висят и тают.</summary>
    public class SmokeCloud : MonoBehaviour
    {
        const float Grow = 0.35f, Hold = 2.6f, Fade = 0.6f;

        Transform[] _puffs;
        Vector3[] _sizes;
        float _born;

        public static void Spawn(Vector3 position, Transform parent)
        {
            var root = new GameObject("Дым");
            root.transform.SetParent(parent, false);
            root.transform.position = position;
            var cloud = root.AddComponent<SmokeCloud>();
            cloud._born = Time.time;

            const int count = 9;
            cloud._puffs = new Transform[count];
            cloud._sizes = new Vector3[count];
            for (int i = 0; i < count; i++)
            {
                Vector2 c = Random.insideUnitCircle * 2.4f;
                var pos = new Vector3(c.x, Random.Range(-0.6f, 0.9f), c.y);
                float grey = Random.Range(0.72f, 0.88f);
                var puff = Shape.Make(PrimitiveType.Sphere, root.transform, pos, Vector3.one * 0.01f,
                    new Color(grey, grey, grey * 0.98f), false, "Клуб");
                cloud._puffs[i] = puff.transform;
                cloud._sizes[i] = Vector3.one * Random.Range(1.4f, 2.4f);
            }
        }

        void Update()
        {
            float t = Time.time - _born;
            float k = t < Grow ? t / Grow : t < Grow + Hold ? 1f : 1f - (t - Grow - Hold) / Fade;
            if (k <= 0f)
            {
                Destroy(gameObject);
                return;
            }
            for (int i = 0; i < _puffs.Length; i++)
            {
                _puffs[i].localScale = _sizes[i] * Mathf.SmoothStep(0f, 1f, k);
                _puffs[i].localPosition += Vector3.up * (0.25f * Time.deltaTime);
            }
        }
    }
}
