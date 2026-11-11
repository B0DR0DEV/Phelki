using System.Collections.Generic;
using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Цветок с пыльцой. Пыльца понемногу отрастает. Пустой цветок «сникает».
    /// Редкий (бабкин) цветок золотой и даёт пыльцу быстрее.
    /// </summary>
    public class Flower : MonoBehaviour
    {
        public bool Rare { get; private set; }
        public bool Blooming { get; private set; }
        public bool HasPollen => Blooming && _pollen >= 1f;
        public bool GrandmasBed { get; private set; }
        public Vector3 HeadPos => _head != null ? _head.position : transform.position + Vector3.up * 0.75f;

        Transform _head;
        Vector3 _headScale;
        readonly List<Renderer> _petals = new List<Renderer>();
        readonly List<Material> _petalMaterials = new List<Material>();
        float _pollen, _max;
        bool _rareSaid;

        public void Init(Transform head, IEnumerable<Renderer> petals, bool grandmasBed)
        {
            _head = head;
            _headScale = head.localScale;
            GrandmasBed = grandmasBed;
            foreach (var r in petals)
            {
                _petals.Add(r);
                _petalMaterials.Add(r.sharedMaterial);
            }
        }

        public void Prepare(bool blooming, bool rare)
        {
            Rare = rare;
            Blooming = blooming;
            _max = rare ? 20f : 6f;
            _pollen = blooming ? _max : 0f;
            _rareSaid = false;

            for (int i = 0; i < _petals.Count; i++)
                _petals[i].sharedMaterial = rare ? Shape.Mat(Palette.Gold, 0.7f) : _petalMaterials[i];
        }

        public int Take(int amount)
        {
            int got = Mathf.Min(amount, Mathf.FloorToInt(_pollen));
            if (got <= 0) return 0;
            _pollen -= got;

            if (Rare && !_rareSaid)
            {
                _rareSaid = true;
                if (GameFlow.I != null) GameFlow.I.Say(Lines.Pick(Lines.Rare));
            }
            return got;
        }

        void Update()
        {
            if (Blooming && _pollen < _max)
                _pollen = Mathf.Min(_max, _pollen + (Rare ? 0.6f : 0.35f) * Time.deltaTime);

            if (_head == null) return;
            float fill = Blooming ? Mathf.Lerp(0.5f, 1f, _pollen / Mathf.Max(1f, _max)) : 0.4f;
            if (Rare) fill *= 1.35f;
            _head.localScale = Vector3.Lerp(_head.localScale, _headScale * fill, 4f * Time.deltaTime);
            if (Rare && Blooming) _head.Rotate(0f, 45f * Time.deltaTime, 0f, Space.World);
        }
    }
}
