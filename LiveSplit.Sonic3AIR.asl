// Autosplitter for Sonic 3: Angel Island Revisited
// Original code taken from the SEGAMasterSplitter by BenInSweden
// Recoding: Jujstme
// contacts: just.tribe@gmail.com
// Version: 1.0.1 (May 5th, 2022)

state("Sonic3AIR") {}

startup
{
    vars.actsName = new string[] {
        "Angel Island Zone - Act 1", "Angel Island Zone - Act 2",
        "Hydrocity Zone - Act 1", "Hydrocity Zone - Act 2",
        "Marble Garden Zone - Act 1", "Marble Garden Zone - Act 2",
        "Carnival Night Zone - Act 1", "Carnival Night Zone - Act 2",
        "Ice Cap Zone - Act 1", "Ice Cap Zone - Act 2",
        "Launch Base Zone - Act 1", "Launch Base Zone - Act 2",
        "Mushroom Hill Zone - Act 1", "Mushroom Hill Zone - Act 2",
        "Flying Battery Zone - Act 1", "Flying Battery Zone - Act 2",
        "Sandopolis Zone - Act 1", "Sandopolis Zone - Act 2",
        "Lava Reef Zone - Act 1", "Lava Reef Zone - Act 2",
        "Hidden Palace Zone", "Sky Sanctuary Zone",
        "Death Egg Zone - Act 1", "Death Egg Zone - Act 2",
        "Doomsday Zone"
    };

    vars.Acts = new Dictionary<int, byte>{
        { 0,   0 }, { 1,   1 },
        { 10,  2 }, { 11,  3 },
        { 20,  4 }, { 21,  5 },
        { 30,  6 }, { 31,  7 },
        { 50,  8 }, { 51,  9 },
        { 60, 10 }, { 61, 11 },
        { 70, 12 }, { 71, 13 },
        { 40, 14 }, { 41, 15 },
        { 80, 16 }, { 81, 17 },
        { 90, 18 }, { 91, 19 }, { 220, 19 },   // Technically, the boss battle in Lava Reef is a separate act
        { 221, 20 }, { 100, 21 }, { 101, 21 }, // Double entry for Sky Sanctuary in order to include Knuckles' version
        { 110, 22 }, { 111, 23 }, { 230, 23 }, // Death Egg Act 2 corresponds to 230 during the boss battle against the giant Egg Robo
        { 120, 24 },
        { 131, 25 } // Ending
    };

    // Makeshift enums important state variables
    vars.State = new ExpandoObject();
    vars.State.SaveSelect = 0x4C;
    vars.State.Loading = 0x8C;
    vars.State.InGame = 0x0C;
    vars.State.SpecialStage = 0x34;
    vars.State.ExitingSpecialStage = 0x48;

    vars.SaveSlotState = new ExpandoObject();
    vars.SaveSlotState.NewGame = 0x80;
    vars.SaveSlotState.InProgress = 0x00;
    vars.SaveSlotState.Complete = 0x01;
    vars.SaveSlotState.CompleteWithEmeralds = 0x02;
    vars.SaveSlotState.CompleteWithSuperEmeralds = 0x03;

    // Custom functions
    vars.ToLittleEndian = (Func<short, short>)(input => {
        byte[] temp = BitConverter.GetBytes(input);
        Array.Reverse(temp);
        return BitConverter.ToInt16(temp, 0);
    });
    vars.TimeBonusTrigger = (Func<bool>)(() => vars.ToLittleEndian(vars.watchers["TimeBonus"].Old) != 0 && vars.ToLittleEndian(vars.watchers["TimeBonus"].Current) == 0 && vars.watchers["EndOfLevelFlag"].Current);

    dynamic[,] Settings =
    {
        { "startOptions", "Auto start settings", null, true },
        { "noSave", "Autostart (No save)", "startOptions", true },
        { "cleanSave", "Autostart (Clean save)", "startOptions", true },
        { "angelIslandSave", "Autostart (Angel Island Zone - No clean save)", "startOptions", true },
        { "newGamePlus", "Autostart (New Game+)",  "startOptions", true },
        { "resetOptions", "Reset options", null, true },
        { "deleteSave", "Reset when deleting a save file", "resetOptions", true },
        { "resetOnNoSave", "Reset when starting a new game without selecting a save", "resetOptions", true },
        { "autosplitting", "Autosplitting options", null, true },      
    };
    for (int i = 0; i < Settings.GetLength(0); i++) settings.Add(Settings[i, 0], Settings[i, 3], Settings[i, 1], Settings[i, 2]);
    for (int i = 0; i < vars.actsName.Length; i++) settings.Add("s" + i.ToString(), true, vars.actsName[i], "autosplitting");

    // Debug functions
    var debug = true; // Easy flag to quickly enable and disable debug outputs
    vars.DebugPrint = (Action<string>)((string obj) => { if (debug) print("[Sonic AIR] " + obj); });
}

init
{
    vars.DebugPrint("Autosplitter Init:");
    refreshRate = 60;
    // timer.Settings.RefreshRate = 60;

    var baseRAM = game.MemoryPages().FirstOrDefault(p => (int)p.RegionSize == 0x521000).BaseAddress;
    if (baseRAM == IntPtr.Zero)
        throw new Exception();
    baseRAM += 0x400020;
    vars.DebugPrint("   => Base RAM address found at 0x" + baseRAM.ToString("X"));

    vars.DebugPrint("   => Setting up MemoryWatchers...");
    vars.watchers = new MemoryWatcherList
    {
        { new MemoryWatcher<byte>(baseRAM + 0xEE4F) { Name = "Act" } },
        { new MemoryWatcher<byte>(baseRAM + 0xEE4E) { Name = "Zone" } },
        { new MemoryWatcher<byte>(baseRAM + 0xF600) { Name = "State" } },
        { new MemoryWatcher<bool>(baseRAM + 0xFAA8) { Name = "EndOfLevelFlag" } },
        { new MemoryWatcher<bool>(baseRAM + 0xEF72) { Name = "GameEndingFlag" } },
        { new MemoryWatcher<bool>(baseRAM + 0xF711) { Name = "LevelStarted" } },
        { new MemoryWatcher<short>(baseRAM + 0xF7D2) { Name = "TimeBonus" } },
        { new MemoryWatcher<byte>(baseRAM + 0xEF4B) { Name = "SaveSelect" } },
    };
    for (int i = 0; i < 8; i++)
    {
        vars.watchers.Add(new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * i) { Name = "ZoneSelectSlot" + i.ToString() });
        vars.watchers.Add(new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * i) { Name = "SaveSlot" + i.ToString() });
    }

    vars.DebugPrint("     => Done");

    // Default act
    current.act = 0;
    vars.DebugPrint("   => Init script completed");
}

update
{
    vars.watchers.UpdateAll(game);

    // Define current Act
    try
    {
        var tempAct = vars.Acts[vars.watchers["Act"].Current + vars.watchers["Zone"].Current * 10];
        current.act =
            tempAct != 0 ? tempAct
            : vars.watchers["LevelStarted"].Current ? 0
            : old.act;
    }
    catch
    {
        current.act = old.act;
    }

    if (current.act != old.act && current.act < vars.actsName.Length)
        vars.DebugPrint("   => Act changed - current act is: " + vars.actsName[current.act]);
}

start
{
    if (vars.watchers["State"].Old == vars.State.SaveSelect && vars.watchers["State"].Current == vars.State.Loading)
    {
        if (vars.watchers["SaveSelect"].Current == 0)
        {
            if (settings["noSave"])
            {
                vars.DebugPrint("   => Run started: no save file");
                return true;
            }
        }
        else
        {
            var newgamepluszoneselector = vars.watchers["ZoneSelectSlot" + (vars.watchers["SaveSelect"].Current - 1).ToString()].Current;
            var saveslotstate = vars.watchers["SaveSlot" + (vars.watchers["SaveSelect"].Current - 1).ToString()].Old;
            if (newgamepluszoneselector == 0)
            {
                if (saveslotstate == vars.SaveSlotState.InProgress)
                {
                    if (settings["angelIslandSave"])
                    {
                        vars.DebugPrint("   => Run started: non-clean save, Angel Island Zone");
                        vars.DebugPrint("     => Save slot selected: " + vars.watchers["SaveSelect"].Current.ToString());
                        return true;
                    }
                }
                else if (saveslotstate == vars.SaveSlotState.NewGame)
                {
                    if (settings["cleanSave"])
                    {
                        vars.DebugPrint("   => Run started: clean save");
                        vars.DebugPrint("     => Save slot selected: " + vars.watchers["SaveSelect"].Current.ToString());
                        return true;
                    }

                }
                else if (settings["newGamePlus"])
                {
                    vars.DebugPrint("   => Run started: new game+");
                    vars.DebugPrint("     => Save slot selected: " + vars.watchers["SaveSelect"].Current.ToString());
                    return true;
                }
            }
        }
    }
}

split
{
    // If current act is 0 (AIZ1 or invalid stage), there's no need to continue
    if (current.act == 0)
        return false;

    // If current act is 21 (Sky Sanctuary) and the ending flag becomes true, trigger Knuckles' ending
    else if (settings["s21"] && current.act == 21 && vars.watchers["GameEndingFlag"].Current && !vars.watchers["GameEndingFlag"].Old )
    {
        vars.DebugPrint("   => Run split - previous act was: Sky Sanctuary (Knuckles' Ending)");
        return true;
    }

    // Special Trigger for Death Egg Zone Act 2 in Act 1: in this case a split needs to be triggered when the Time Bonus drops to zero, in accordance to speedrun.com rulings
    if (settings["s23"] && old.act == 23 && vars.TimeBonusTrigger())
    {
        vars.DebugPrint("   => Run split - previous act was: " + vars.actsName[old.act]);
        return true;
    }

    // Normal splitting condition: trigger a split whenever the act changes
    if (old.act != current.act)
    {
        if (settings["s0"] && vars.watchers["EndOfLevelFlag"].Old && old.act == 0)
        {
            vars.DebugPrint("   => Run split - previous act was: " + vars.actsName[old.act]);
            return true;
        }
        else if (settings["s" + old.act.ToString()])
        {
            vars.DebugPrint("   => Run split - previous act was: " + vars.actsName[old.act]);
            return true;
        }
    }
}

reset
{
    if (vars.watchers["SaveSelect"].Current == 0)
    {
        if (vars.watchers["State"].Old == vars.State.SaveSelect &&
            vars.watchers["State"].Current == vars.State.Loading &&
            settings["resetOnNoSave"])
        {
            vars.DebugPrint("   => Run reset: selected no-save run");
            return true;
        }
    }
    else if (vars.watchers["SaveSelect"].Current > 0 && vars.watchers["SaveSelect"].Current <= 8 && !vars.watchers["SaveSelect"].Changed)
    {
        if (vars.watchers["SaveSlot" + (vars.watchers["SaveSelect"].Current - 1).ToString()].Old != vars.SaveSlotState.NewGame &&
            vars.watchers["SaveSlot" + (vars.watchers["SaveSelect"].Current - 1).ToString()].Current == vars.SaveSlotState.NewGame &&
            settings["deleteSave"])
        {
            vars.DebugPrint("   => Run reset: deleted save file");
            vars.DebugPrint("     => Save slot selected: " + vars.watchers["SaveSelect"].Current.ToString());
            return true;
        }
    }
}
