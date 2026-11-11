using UnityEngine;

namespace Phelki
{
    /// <summary>
    /// Запускает игру в любой сцене: открыл сцену, нажал Play — и всё собирается само.
    /// Если в сцене есть объект с ManualSceneMarker, автосборка отключается.
    /// </summary>
    public static class Bootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Run()
        {
            if (Object.FindFirstObjectByType<GameFlow>() != null) return;
            if (Object.FindFirstObjectByType<ManualSceneMarker>() != null) return;

            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Screen.orientation = ScreenOrientation.Portrait;

            var root = new GameObject("Phelki");
            root.AddComponent<GameFlow>().Init();
        }
    }
}
