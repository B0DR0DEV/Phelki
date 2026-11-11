using UnityEngine;

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
    }
}
