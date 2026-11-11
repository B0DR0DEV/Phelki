using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Phelki
{
    /// <summary>
    /// Помощники для интерфейса, собранного кодом. Скруглённые плашки рисуются
    /// программно, шрифт — встроенный динамический (поддерживает кириллицу).
    /// Позиции задаются долями экрана: (0,0) — левый низ, (1,1) — правый верх.
    /// </summary>
    public static class UiKit
    {
        public static readonly Color HoneyBg = new Color(1f, 0.76f, 0.15f);
        public static readonly Color Ink = new Color(0.16f, 0.11f, 0.05f);
        public static readonly Color Shade = new Color(0.08f, 0.06f, 0.03f, 0.62f);
        public static readonly Color Muted = new Color(0.55f, 0.52f, 0.48f);
        public static readonly Color DangerBg = new Color(0.72f, 0.24f, 0.2f);

        static Font _font;
        static Sprite _rounded, _triangle;

        public static Font Font
        {
            get
            {
                if (_font == null) _font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
                return _font;
            }
        }

        public static Sprite Rounded
        {
            get
            {
                if (_rounded == null) _rounded = MakeRounded(64, 26);
                return _rounded;
            }
        }

        public static Sprite Triangle
        {
            get
            {
                if (_triangle == null) _triangle = MakeTriangle(64);
                return _triangle;
            }
        }

        public static void EnsureEventSystem()
        {
            if (Object.FindFirstObjectByType<EventSystem>() != null) return;
            var go = new GameObject("EventSystem");
            go.AddComponent<EventSystem>();
#if ENABLE_INPUT_SYSTEM
            go.AddComponent<UnityEngine.InputSystem.UI.InputSystemUIInputModule>();
#else
            go.AddComponent<StandaloneInputModule>();
#endif
        }

        public static RectTransform Area(string name, Transform parent, Vector2 min, Vector2 max)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = (RectTransform)go.transform;
            rt.SetParent(parent, false);
            rt.anchorMin = min;
            rt.anchorMax = max;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
            return rt;
        }

        public static Image Panel(Transform parent, string name, Vector2 min, Vector2 max, Color color,
            bool rounded = true)
        {
            var rt = Area(name, parent, min, max);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = color;
            img.raycastTarget = false;
            if (rounded)
            {
                img.sprite = Rounded;
                img.type = Image.Type.Sliced;
                img.pixelsPerUnitMultiplier = 0.6f;
            }
            return img;
        }

        public static Text Label(Transform parent, string text, int size, Vector2 min, Vector2 max,
            TextAnchor align = TextAnchor.MiddleCenter, Color? color = null, FontStyle style = FontStyle.Normal,
            bool outline = true)
        {
            var rt = Area("Текст", parent, min, max);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = Font;
            t.text = text;
            t.fontSize = size;
            t.fontStyle = style;
            t.alignment = align;
            t.color = color ?? Color.white;
            t.horizontalOverflow = HorizontalWrapMode.Wrap;
            t.verticalOverflow = VerticalWrapMode.Truncate;
            t.resizeTextForBestFit = true;
            t.resizeTextMinSize = Mathf.Max(14, size / 2);
            t.resizeTextMaxSize = size;
            t.raycastTarget = false;
            if (outline)
            {
                var o = rt.gameObject.AddComponent<Outline>();
                o.effectColor = new Color(0f, 0f, 0f, 0.45f);
                o.effectDistance = new Vector2(2f, -2f);
            }
            return t;
        }

        public static Button MakeButton(Transform parent, string text, Vector2 min, Vector2 max, Color bg, Color fg,
            UnityAction onClick, int size = 56)
        {
            var img = Panel(parent, "Кнопка", min, max, bg);
            img.raycastTarget = true;
            var b = img.gameObject.AddComponent<Button>();
            b.targetGraphic = img;
            var colors = b.colors;
            colors.pressedColor = new Color(0.8f, 0.8f, 0.8f);
            colors.disabledColor = new Color(0.75f, 0.75f, 0.75f, 0.6f);
            colors.fadeDuration = 0.06f;
            b.colors = colors;
            if (onClick != null) b.onClick.AddListener(onClick);

            var label = Label(img.transform, text, size, new Vector2(0.04f, 0.05f), new Vector2(0.96f, 0.95f),
                TextAnchor.MiddleCenter, fg, FontStyle.Bold, false);
            label.name = "Подпись";
            return b;
        }

        public static void Stretch(RectTransform rt)
        {
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }

        static Sprite MakeRounded(int size, int radius)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };
            var px = new Color32[size * size];
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float cx = Mathf.Clamp(x + 0.5f, radius, size - radius);
                float cy = Mathf.Clamp(y + 0.5f, radius, size - radius);
                float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy));
                float a = Mathf.Clamp01(radius - d + 0.5f);
                px[y * size + x] = new Color32(255, 255, 255, (byte)(a * 255));
            }
            tex.SetPixels32(px);
            tex.Apply();
            return Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f, 0,
                SpriteMeshType.FullRect, new Vector4(radius + 2, radius + 2, radius + 2, radius + 2));
        }

        static Sprite MakeTriangle(int size)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear };
            var px = new Color32[size * size];
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                // Треугольник остриём вверх
                float halfWidth = (1f - (y + 0.5f) / size) * size * 0.5f;
                float dx = Mathf.Abs(x + 0.5f - size * 0.5f);
                float a = Mathf.Clamp01(halfWidth - dx + 0.5f);
                px[y * size + x] = new Color32(255, 255, 255, (byte)(a * 255));
            }
            tex.SetPixels32(px);
            tex.Apply();
            return Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f);
        }
    }
}
