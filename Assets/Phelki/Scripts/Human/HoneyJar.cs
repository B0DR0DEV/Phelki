using UnityEngine;

namespace Phelki
{
    /// <summary>Банка мёда, которую дачник должен утащить. Подобрал — пробежав рядом.</summary>
    public class HoneyJar : MonoBehaviour
    {
        Transform _visual;
        float _phase;

        public static HoneyJar Spawn(Transform parent, Vector3 position)
        {
            var root = new GameObject("Банка мёда");
            root.transform.SetParent(parent, false);
            root.transform.position = position;

            var visual = Shape.Node("Вид", root.transform, new Vector3(0f, 0.6f, 0f));
            var art = PhelkiArtSet.Current;
            if (art != null && art.honeyJar != null) Shape.PlaceModel(art.honeyJar, visual, Vector3.zero, 0f, false);
            else
            {
                Shape.Make(PrimitiveType.Cylinder, visual, Vector3.zero, new Vector3(0.36f, 0.24f, 0.36f), Palette.Honey, false, "Мёд");
                Shape.Make(PrimitiveType.Cylinder, visual, new Vector3(0f, 0.27f, 0f), new Vector3(0.38f, 0.04f, 0.38f),
                    Palette.Red, false, "Крышка");
                Shape.Make(PrimitiveType.Cube, visual, new Vector3(0f, 0.02f, -0.18f), new Vector3(0.22f, 0.16f, 0.01f),
                    Palette.White, false, "Этикетка");
            }
            // Маячок, чтобы банку было видно издалека
            Shape.Make(PrimitiveType.Sphere, visual, new Vector3(0f, 1.1f, 0f), Vector3.one * 0.22f, Palette.Gold, false, "Маячок");

            var trigger = root.AddComponent<SphereCollider>();
            trigger.isTrigger = true;
            trigger.center = new Vector3(0f, 0.8f, 0f);
            trigger.radius = 1.1f;

            var jar = root.AddComponent<HoneyJar>();
            jar._visual = visual;
            jar._phase = Random.value * 10f;
            return jar;
        }

        void Update()
        {
            if (_visual == null) return;
            _visual.localPosition = new Vector3(0f, 0.6f + Mathf.Sin(Time.time * 2.2f + _phase) * 0.12f, 0f);
            _visual.Rotate(0f, 70f * Time.deltaTime, 0f, Space.World);
        }

        void OnTriggerEnter(Collider other)
        {
            var human = other.GetComponentInParent<HumanController>();
            if (human == null || human.Frozen) return;
            var match = GameFlow.I != null ? GameFlow.I.Escape : null;
            if (match == null) return;

            match.OnJarTaken(this);
            Destroy(gameObject);
        }
    }
}
