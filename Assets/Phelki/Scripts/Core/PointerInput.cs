using UnityEngine;
using UnityEngine.EventSystems;

namespace Phelki
{
    /// <summary>
    /// Один палец (или мышь в редакторе). Работает и с новой системой ввода
    /// (Input System), и со старой — смотря что включено в проекте.
    /// </summary>
    public static class PointerInput
    {
        public static bool Pressed(out Vector2 position)
        {
#if ENABLE_INPUT_SYSTEM
            var pointer = UnityEngine.InputSystem.Pointer.current;
            if (pointer == null)
            {
                position = Vector2.zero;
                return false;
            }
            position = pointer.position.ReadValue();
            return pointer.press.isPressed;
#else
            if (Input.touchCount > 0)
            {
                position = Input.GetTouch(0).position;
                return true;
            }
            position = Input.mousePosition;
            return Input.GetMouseButton(0);
#endif
        }

        /// <summary>Палец сейчас над кнопкой или панелью интерфейса.</summary>
        public static bool OverUI()
        {
            var es = EventSystem.current;
            if (es == null) return false;
#if ENABLE_INPUT_SYSTEM
            return es.IsPointerOverGameObject();
#else
            if (Input.touchCount > 0) return es.IsPointerOverGameObject(Input.GetTouch(0).fingerId);
            return es.IsPointerOverGameObject();
#endif
        }
    }

    /// <summary>
    /// Отслеживает одно касание: где палец, не начато ли оно на кнопке
    /// интерфейса (тогда персонажем не управляем), и был ли быстрый свайп.
    /// </summary>
    public class FingerTracker
    {
        public bool Pressed { get; private set; }
        public Vector2 Position { get; private set; }

        readonly System.Collections.Generic.Queue<(float t, Vector2 p)> _samples =
            new System.Collections.Generic.Queue<(float t, Vector2 p)>();

        bool _wasDown, _onUI, _swipeUsed;

        /// <summary>Вызывать раз в кадр. Возвращает направление свайпа (или ноль).</summary>
        public Vector2 Update(bool active, float swipeScreensPerSecond = 2.4f)
        {
            bool down = PointerInput.Pressed(out var pos) && active;
            if (down && !_wasDown) _onUI = PointerInput.OverUI();
            _wasDown = down;

            Pressed = down && !_onUI;
            Position = pos;

            if (!Pressed)
            {
                _samples.Clear();
                _swipeUsed = false;
                return Vector2.zero;
            }

            _samples.Enqueue((Time.time, pos));
            while (_samples.Count > 0 && Time.time - _samples.Peek().t > 0.12f) _samples.Dequeue();

            if (_swipeUsed || _samples.Count < 2) return Vector2.zero;
            var first = _samples.Peek();
            float dt = Time.time - first.t;
            if (dt <= 0.02f) return Vector2.zero;

            Vector2 v = (pos - first.p) / dt;
            if (v.magnitude < Screen.height * swipeScreensPerSecond) return Vector2.zero;
            _swipeUsed = true;
            return v.normalized;
        }

        /// <summary>Точка под пальцем на горизонтальной плоскости заданной высоты.</summary>
        public static bool ToPlane(Camera cam, Vector2 screen, float height, out Vector3 point)
        {
            point = default;
            if (cam == null) return false;
            var ray = cam.ScreenPointToRay(screen);
            var plane = new Plane(Vector3.up, new Vector3(0f, height, 0f));
            if (!plane.Raycast(ray, out float enter)) return false;
            point = ray.GetPoint(enter);
            return true;
        }

        /// <summary>Направление на экране → направление по земле с учётом камеры.</summary>
        public static Vector3 ScreenDirToWorld(Camera cam, Vector2 dir)
        {
            if (cam == null) return Vector3.zero;
            Vector3 right = Vector3.ProjectOnPlane(cam.transform.right, Vector3.up).normalized;
            Vector3 forward = Vector3.ProjectOnPlane(cam.transform.forward, Vector3.up).normalized;
            Vector3 d = right * dir.x + forward * dir.y;
            return d.sqrMagnitude > 0.0001f ? d.normalized : Vector3.zero;
        }
    }
}
