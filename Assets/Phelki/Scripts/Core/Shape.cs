using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Временные модели-заглушки и материалы. Материал берётся из стандартного
    /// материала текущего конвейера рендера (URP или встроенного), поэтому
    /// шейдер всегда правильный и попадает в сборку.
    /// Когда появятся настоящие модели, их подключают через PhelkiArtSet.
    /// </summary>
    public static class Shape
    {
        static Material _baseMaterial;
        static readonly Dictionary<(Color, float), Material> Cache = new Dictionary<(Color, float), Material>();

        public static Material Mat(Color color, float smoothness = 0.15f)
        {
            var key = (color, smoothness);
            if (Cache.TryGetValue(key, out var cached) && cached != null) return cached;

            if (_baseMaterial == null)
            {
                var probe = GameObject.CreatePrimitive(PrimitiveType.Cube);
                _baseMaterial = new Material(probe.GetComponent<Renderer>().sharedMaterial);
                Object.DestroyImmediate(probe);
            }

            var m = new Material(_baseMaterial) { color = color };
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", color);
            if (m.HasProperty("_Smoothness")) m.SetFloat("_Smoothness", smoothness);
            if (m.HasProperty("_Glossiness")) m.SetFloat("_Glossiness", smoothness);
            Cache[key] = m;
            return m;
        }

        /// <summary>Создаёт примитив. collider=false — только для красоты.</summary>
        public static GameObject Make(PrimitiveType type, Transform parent, Vector3 localPos, Vector3 localScale,
            Color color, bool collider = false, string name = null, Vector3? localEuler = null)
        {
            var go = GameObject.CreatePrimitive(type);
            if (name != null) go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localScale = localScale;
            if (localEuler.HasValue) go.transform.localEulerAngles = localEuler.Value;
            go.GetComponent<Renderer>().sharedMaterial = Mat(color);
            if (!collider)
            {
                var c = go.GetComponent<Collider>();
                if (c != null) Object.DestroyImmediate(c);
            }
            return go;
        }

        /// <summary>Пустой узел-контейнер.</summary>
        public static Transform Node(string name, Transform parent, Vector3 localPos)
        {
            var t = new GameObject(name).transform;
            t.SetParent(parent, false);
            t.localPosition = localPos;
            return t;
        }

        /// <summary>
        /// Ставит настоящую модель из набора арта. Если у модели нет коллайдера,
        /// добавляет коробку по её размерам, чтобы в неё можно было врезаться.
        /// </summary>
        public static GameObject PlaceModel(GameObject prefab, Transform parent, Vector3 localPos, float yaw = 0f,
            bool solid = true)
        {
            var go = Object.Instantiate(prefab, parent, false);
            go.transform.localPosition = localPos;
            go.transform.localEulerAngles = new Vector3(0f, yaw, 0f);
            if (solid && go.GetComponentInChildren<Collider>() == null)
            {
                var renderers = go.GetComponentsInChildren<Renderer>();
                if (renderers.Length > 0)
                {
                    var b = renderers[0].bounds;
                    foreach (var r in renderers) b.Encapsulate(r.bounds);
                    var box = go.AddComponent<BoxCollider>();
                    box.center = go.transform.InverseTransformPoint(b.center);
                    var s = go.transform.lossyScale;
                    box.size = new Vector3(b.size.x / Mathf.Max(0.0001f, s.x), b.size.y / Mathf.Max(0.0001f, s.y),
                        b.size.z / Mathf.Max(0.0001f, s.z));
                }
            }
            return go;
        }
    }

    public static class Palette
    {
        public static readonly Color Grass = new Color(0.45f, 0.72f, 0.33f);
        public static readonly Color GrassDark = new Color(0.33f, 0.58f, 0.26f);
        public static readonly Color Path = new Color(0.78f, 0.68f, 0.52f);
        public static readonly Color Wood = new Color(0.62f, 0.44f, 0.27f);
        public static readonly Color WoodLight = new Color(0.86f, 0.70f, 0.46f);
        public static readonly Color Roof = new Color(0.70f, 0.25f, 0.20f);
        public static readonly Color Wall = new Color(0.93f, 0.88f, 0.76f);
        public static readonly Color Glass = new Color(0.62f, 0.84f, 0.95f);
        public static readonly Color Honey = new Color(1.00f, 0.74f, 0.12f);
        public static readonly Color BeeYellow = new Color(1.00f, 0.80f, 0.18f);
        public static readonly Color Black = new Color(0.10f, 0.09f, 0.08f);
        public static readonly Color Wing = new Color(0.85f, 0.95f, 1.00f);
        public static readonly Color Leaf = new Color(0.25f, 0.55f, 0.22f);
        public static readonly Color Trunk = new Color(0.45f, 0.30f, 0.18f);
        public static readonly Color Jam = new Color(0.65f, 0.08f, 0.15f);
        public static readonly Color Metal = new Color(0.55f, 0.58f, 0.62f);
        public static readonly Color Red = new Color(0.90f, 0.20f, 0.18f);
        public static readonly Color White = new Color(0.97f, 0.97f, 0.95f);
        public static readonly Color Gold = new Color(1.00f, 0.84f, 0.20f);
    }
}
