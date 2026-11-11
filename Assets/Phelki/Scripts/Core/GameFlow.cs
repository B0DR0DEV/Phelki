using UnityEngine;

namespace Phelki
{
    public class SortieStats
    {
        public int pollenCollected;
        public int honeyMade;
        public int pollenLost;
        public int pollenStolen;
        public int crashes;
        public int deposits;
        public int waspsRammed;
    }

    /// <summary>
    /// Главный дирижёр: вопрос → пасека (меню) → вылет → итоги.
    /// </summary>
    public class GameFlow : MonoBehaviour
    {
        public enum State
        {
            Question,
            Hub,
            Sortie,
            Results
        }

        public static GameFlow I { get; private set; }

        public float sortieLength = 180f;

        public State Current { get; private set; }
        public World World { get; private set; }
        public BeeController Bee { get; private set; }
        public FollowCamera Cam { get; private set; }
        public Screens Ui { get; private set; }
        public SortieStats Stats { get; private set; }
        public float TimeLeft { get; private set; }

        bool _timeLowSaid;

        void Awake()
        {
            I = this;
        }

        public void Init()
        {
            World = World.Build(transform);
            Cam = FollowCamera.Setup(World);
            Ui = Screens.Create();

            if (PlayerProfile.Current.Side == Side.None) ShowQuestion();
            else ShowHub();
        }

        public void ShowQuestion()
        {
            Current = State.Question;
            Cam.ShowHub();
            Ui.ShowQuestion();
        }

        public void Answer(Side side)
        {
            PlayerProfile.Current.Answer(side);
            Say(Lines.Pick(side == Side.Bee ? Lines.AnsweredBee : Lines.AnsweredHuman), 3f);
            if (side == Side.Human) World.AngerBees();
            ShowHub();
        }

        public void ShowHub()
        {
            Current = State.Hub;
            Cam.ShowHub();
            Ui.ShowHub();
        }

        public void StartSortie()
        {
            if (PlayerProfile.Current.Side != Side.Bee) return;

            Stats = new SortieStats();
            TimeLeft = sortieLength;
            _timeLowSaid = false;
            World.PrepareSortie();
            Bee = BeeController.Spawn(World.BeeSpawn);
            Cam.Follow(Bee.transform);
            Current = State.Sortie;
            Ui.ShowHud();
        }

        public void EndSortie()
        {
            if (Current != State.Sortie) return;

            if (Bee != null)
            {
                // Пыльца, не донесённая до улья, пропадает.
                Stats.pollenLost += Bee.Pollen;
                Destroy(Bee.gameObject);
                Bee = null;
            }
            World.EndSortie();

            var p = PlayerProfile.Current;
            p.honey += Stats.honeyMade;
            p.sorties++;
            bool record = Stats.honeyMade > p.bestSortieHoney;
            if (record) p.bestSortieHoney = Stats.honeyMade;
            p.Save();

            Current = State.Results;
            Cam.ShowHub();
            Ui.ShowResults(Stats, record);
        }

        void Update()
        {
            if (Current != State.Sortie) return;

            TimeLeft -= Time.deltaTime;
            if (!_timeLowSaid && TimeLeft < 20f)
            {
                _timeLowSaid = true;
                Say(Lines.Pick(Lines.TimeLow));
            }
            if (TimeLeft <= 0f) EndSortie();
        }

        public void Say(string line, float seconds = 2.5f)
        {
            if (Ui != null) Ui.Say(line, seconds);
        }

        public void Toast(string text)
        {
            if (Ui != null) Ui.Toast(text);
        }
    }
}
