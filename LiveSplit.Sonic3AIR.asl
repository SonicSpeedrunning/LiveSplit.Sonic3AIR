// Autosplitter for Sonic 3: Angel Island Revisited
// Original code taken from the SEGAMasterSplitter by BenInSweden
// Recoding: Jujstme
// contacts: just.tribe@gmail.com
// Version: 1.0.0 (Apr 9th, 2022)

state("Sonic3AIR") {}

startup
{
    string[] actsName = {
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
        { "autosplitting", "Autosplitting options", null, true },      
    };
    for (int i = 0; i < Settings.GetLength(0); i++) settings.Add(Settings[i, 0], Settings[i, 3], Settings[i, 1], Settings[i, 2]);
    for (int i = 0; i < actsName.Length; i++) settings.Add("s" + i.ToString(), true, actsName[i], "autosplitting");
}

init
{
    var baseRAM = game.MemoryPages().FirstOrDefault(p => (int)p.RegionSize == 0x521000).BaseAddress;
    if (baseRAM == IntPtr.Zero)
        throw new Exception();
    baseRAM += 0x400020;

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
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 0) { Name = "ZoneSelectSlot0" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 1) { Name = "ZoneSelectSlot1" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 2) { Name = "ZoneSelectSlot2" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 3) { Name = "ZoneSelectSlot3" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 4) { Name = "ZoneSelectSlot4" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 5) { Name = "ZoneSelectSlot5" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 6) { Name = "ZoneSelectSlot6" } },
        { new MemoryWatcher<byte>(baseRAM + 0xB15F + 0x4A * 7) { Name = "ZoneSelectSlot7" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 0) { Name = "SaveSlot0" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 1) { Name = "SaveSlot1" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 2) { Name = "SaveSlot2" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 3) { Name = "SaveSlot3" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 4) { Name = "SaveSlot4" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 5) { Name = "SaveSlot5" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 6) { Name = "SaveSlot6" } },
        { new MemoryWatcher<byte>(baseRAM + 0xE6AC + 0xA * 7) { Name = "SaveSlot7" } },
    };

    // Default act
    current.act = 0;
}

update
{
    vars.watchers.UpdateAll(game);
}

start
{
    if (vars.watchers["State"].Old == vars.State.SaveSelect && vars.watchers["State"].Current == vars.State.Loading)
    {
        if (vars.watchers["SaveSelect"].Current == 0)
            return settings["noSave"];
        else
        {
            var newgamepluszoneselector = vars.watchers["ZoneSelectSlot" + (vars.watchers["SaveSelect"].Current - 1).ToString()].Current;
            var saveslotstate = vars.watchers["SaveSlot" + (vars.watchers["SaveSelect"].Current - 1).ToString()].Old;
            if (newgamepluszoneselector == 0)
                return
                    saveslotstate == vars.SaveSlotState.InProgress ? settings["angelIslandSave"] :
                    saveslotstate == vars.SaveSlotState.NewGame ? settings["cleanSave"] :
                    settings["newGamePlus"];
        }
    }
}

split
{
    // Define current Act
    try
    {
        current.act = vars.Acts[vars.watchers["Act"].Current + vars.watchers["Zone"].Current * 10];
    }
    catch
    {
        current.act = 0;
    }

    // If current act is 0 (AIZ1 or invalid stage), there's no need to continue
    if (current.act == 0)
        return false;
    // If current act is 21 (Sky Sanctuary) and the ending flag becomes true, trigger Knuckles' ending
    else if (current.act == 21 && vars.watchers["GameEndingFlag"].Current && !vars.watchers["GameEndingFlag"].Old)
        return settings["s21"];

    // Special Trigger for Death Egg Zone Act 2 in Act 1: in this case a split needs to be triggered when the Time Bonus drops to zero, in accordance to speedrun.com rulings
    if (old.act == 23 && vars.TimeBonusTrigger())
        return settings["s23"];

    // Normal splitting condition: trigger a split whenever the act changes
    if (old.act != current.act)
    {
        if (old.act == 0)
            return vars.watchers["EndOfLevelFlag"].Old && settings["s0"];
        else
            return settings["s" + old.act.ToString()];
    }
}
