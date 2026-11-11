using UnityEngine;

namespace Phelki
{
    /// <summary>Крутит объект вокруг своей оси (лопасти вентилятора).</summary>
    public class Spinner : MonoBehaviour
    {
        public Vector3 axis = Vector3.forward;
        public float speed = 720f;

        void Update() => transform.Rotate(axis, speed * Time.deltaTime, Space.Self);
    }
}
