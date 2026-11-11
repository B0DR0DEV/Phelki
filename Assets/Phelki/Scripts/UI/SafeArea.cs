using UnityEngine;

namespace Phelki
{
    /// <summary>Держит интерфейс внутри безопасной зоны экрана (вырез камеры, жесты).</summary>
    [RequireComponent(typeof(RectTransform))]
    public class SafeArea : MonoBehaviour
    {
        Rect _applied;
        Vector2Int _screen;

        void Update()
        {
            var safe = Screen.safeArea;
            if (safe == _applied && _screen.x == Screen.width && _screen.y == Screen.height) return;
            if (Screen.width <= 0 || Screen.height <= 0) return;

            _applied = safe;
            _screen = new Vector2Int(Screen.width, Screen.height);
            var rt = (RectTransform)transform;
            rt.anchorMin = new Vector2(safe.xMin / Screen.width, safe.yMin / Screen.height);
            rt.anchorMax = new Vector2(safe.xMax / Screen.width, safe.yMax / Screen.height);
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }
    }
}
