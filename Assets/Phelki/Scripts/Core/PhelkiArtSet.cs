using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Набор настоящих моделей. Создай его: Assets → Create → Phelki → Набор арта,
    /// назови файл PhelkiArtSet и положи в папку Assets/Phelki/Resources.
    /// Любое пустое поле игра заменит временной заглушкой.
    /// </summary>
    [CreateAssetMenu(fileName = "PhelkiArtSet", menuName = "Phelki/Набор арта")]
    public class PhelkiArtSet : ScriptableObject
    {
        [Header("Персонажи (смотрят вперёд по оси Z, размер пчелы ~0.8 м)")]
        public GameObject bee;
        public GameObject wasp;
        [Tooltip("Дачник за сторону людей, рост ~2 м, ноги на нуле")]
        public GameObject human;

        [Header("Пасека")]
        public GameObject hive;
        public GameObject flower;
        public GameObject rareFlower;

        [Header("Дача")]
        public GameObject house;
        public GameObject greenhouse;
        public GameObject tree;
        public GameObject table;
        public GameObject jamJar;
        public GameObject fan;
        public GameObject trashCan;
        public GameObject car;
        public GameObject honeyJar;

        static PhelkiArtSet _loaded;
        static bool _tried;

        public static PhelkiArtSet Current
        {
            get
            {
                if (!_tried)
                {
                    _tried = true;
                    _loaded = Resources.Load<PhelkiArtSet>("PhelkiArtSet");
                }
                return _loaded;
            }
        }
    }
}
