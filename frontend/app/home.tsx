import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import * as ScreenOrientation from "expo-screen-orientation";
import { useEffect, useMemo, useState } from "react";
import { LandingScreen } from "../components/LandingScreen";
import {
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from "react-native";

type TabKey = "home" | "world" | "settings";
type TabIcon = keyof typeof Ionicons.glyphMap;

const tabs: Array<{ key: TabKey; label: string; icon: TabIcon }> = [
  { key: "home", label: "Home", icon: "home-outline" },
  { key: "world", label: "World", icon: "map-outline" },
  { key: "settings", label: "Settings", icon: "settings-outline" },
];

const avatarOptions = [
  { bg: "#ffb72b", body: "#48bd67", accent: "#f7ffe8" },
  { bg: "#46a7f2", body: "#ffd151", accent: "#12213d" },
  { bg: "#a64acb", body: "#6ee7a7", accent: "#fff7e0" },
];

export default function TrainerHome() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<TabKey>("home");
  const [username, setUsername] = useState("Trainer Alex");
  const [draftName, setDraftName] = useState(username);
  const [editingName, setEditingName] = useState(false);
  const [grade, setGrade] = useState(8);
  const [avatarIndex, setAvatarIndex] = useState(0);
  const [soundEffects, setSoundEffects] = useState(true);
  const [darkMode, setDarkMode] = useState(false);
  const [notifications, setNotifications] = useState(true);
  const [language, setLanguage] = useState<"English" | "Filipino">("English");
  const [showLanguageChoices, setShowLanguageChoices] = useState(false);
  const [showAbout, setShowAbout] = useState(false);

  const avatar = avatarOptions[avatarIndex];
  const firstName = useMemo(() => username.split(" ")[0] || "Trainer", [username]);

  useEffect(() => {
    if (Platform.OS !== "web") {
      void ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT_UP);
    }
  }, []);

  const saveUsername = () => {
    const nextName = draftName.trim();

    if (nextName.length > 0) {
      setUsername(nextName);
    } else {
      setDraftName(username);
    }

    setEditingName(false);
  };

  const cycleAvatar = () => {
    setAvatarIndex((current) => (current + 1) % avatarOptions.length);
  };

  const cycleGrade = () => {
    setGrade((current) => (current >= 10 ? 7 : current + 1));
  };

  return (
    <SafeAreaView style={[styles.app, darkMode && styles.appDark]}>
      <View style={styles.statusBar}>
        <Text style={[styles.statusTime, darkMode && styles.textOnDark]}>23:45</Text>
        <View style={styles.statusIcons}>
          <View style={[styles.signalBars, darkMode && styles.statusPale]} />
          <View style={[styles.signalBarsSmall, darkMode && styles.statusPale]} />
          <View style={[styles.battery, darkMode && styles.batteryDark]} />
        </View>
      </View>

      <View style={styles.content}>
        {activeTab === "home" ? (
          <HomeScreen
            avatar={avatar}
            darkMode={darkMode}
            firstName={firstName}
            grade={grade}
            username={username}
            onOpenSettings={() => setActiveTab("settings")}
            onOpenWorld={() => setActiveTab("world")}
          />
        ) : null}

        {activeTab === "world" ? (
          <WorldScreen onStart={() => router.push("/game")} />
        ) : null}

        {activeTab === "settings" ? (
          <SettingsScreen
            avatar={avatar}
            darkMode={darkMode}
            draftName={draftName}
            editingName={editingName}
            grade={grade}
            language={language}
            notifications={notifications}
            showAbout={showAbout}
            showLanguageChoices={showLanguageChoices}
            soundEffects={soundEffects}
            username={username}
            onCancelName={() => {
              setDraftName(username);
              setEditingName(false);
            }}
            onChangeAvatar={cycleAvatar}
            onChangeDraftName={setDraftName}
            onCycleGrade={cycleGrade}
            onEditName={() => setEditingName(true)}
            onSaveName={saveUsername}
            onSelectLanguage={(nextLanguage) => {
              setLanguage(nextLanguage);
              setShowLanguageChoices(false);
            }}
            onToggleAbout={() => setShowAbout((current) => !current)}
            onToggleDark={setDarkMode}
            onToggleLanguageChoices={() => setShowLanguageChoices((current) => !current)}
            onToggleNotifications={setNotifications}
            onToggleSound={setSoundEffects}
          />
        ) : null}
      </View>

      <View style={[styles.tabBar, darkMode && styles.tabBarDark]}>
        {tabs.map((tab) => {
          const active = activeTab === tab.key;

          return (
            <Pressable
              key={tab.key}
              onPress={() => setActiveTab(tab.key)}
              style={({ pressed }) => [
                styles.tabButton,
                active && styles.tabButtonActive,
                pressed && styles.pressed,
              ]}
            >
              <View style={[styles.tabMarker, active && styles.tabMarkerActive]}>
                <Ionicons name={tab.icon} size={18} color={active ? "#ffffff" : "#8aa0bd"} />
              </View>
              <Text style={[styles.tabLabel, darkMode && styles.textMutedDark, active && styles.tabLabelActive]}>
                {tab.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </SafeAreaView>
  );
}

function HomeScreen({
  avatar,
  darkMode,
  firstName,
  grade,
  username,
  onOpenSettings,
  onOpenWorld,
}: {
  avatar: (typeof avatarOptions)[number];
  darkMode: boolean;
  firstName: string;
  grade: number;
  username: string;
  onOpenSettings: () => void;
  onOpenWorld: () => void;
}) {
  return (
    <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
      <View style={styles.homeHeader}>
        <View>
          <Text style={[styles.greeting, darkMode && styles.textOnDark]}>Hey, {firstName}!</Text>
          <Text style={[styles.subtleText, darkMode && styles.textMutedDark]}>Ready to level up?</Text>
        </View>
        <View style={[styles.notificationButton, darkMode && styles.notificationDark]}>
          <Text style={styles.notificationText}>!</Text>
          <View style={styles.notificationDot} />
        </View>
      </View>

      <View style={styles.profileCard}>
        <PixelAvatar avatar={avatar} size={58} />
        <View style={styles.profileCardInfo}>
          <View style={styles.profileTitleRow}>
            <Text style={styles.profileName}>{username}</Text>
            <View style={styles.gradeChip}>
              <Text style={styles.gradeChipText}>Gr.{grade}</Text>
            </View>
          </View>
          <Text style={styles.profileRegion}>Volcano Highlands</Text>
          <View style={styles.xpTrack}>
            <View style={styles.xpFill} />
          </View>
          <Text style={styles.profileMetric}>340/500 XP</Text>
        </View>
      </View>

      <Text style={[styles.sectionTitle, darkMode && styles.textOnDark]}>Quick Actions</Text>
      <View style={styles.actionGrid}>
        <ActionButton label="Continue Adventure" tone="yellow" marker=">" onPress={onOpenWorld} />
        <ActionButton label="My Profile" tone="purple" marker="@" onPress={onOpenSettings} />
      </View>

      <Text style={[styles.sectionTitle, darkMode && styles.textOnDark]}>Your Stats</Text>
      <View style={styles.statsGrid}>
        <StatCard darkMode={darkMode} label="Monsters Defeated" value="3" marker="X" tone="#ef4444" />
        <StatCard darkMode={darkMode} label="Questions Done" value="47" marker="Q" tone="#3b82f6" />
        <StatCard darkMode={darkMode} label="Accuracy" value="78%" marker="O" tone="#22c55e" />
        <StatCard darkMode={darkMode} label="Streak" value="5" marker="F" tone="#f97316" />
      </View>

      <View style={[styles.progressCard, darkMode && styles.cardDark]}>
        <View style={styles.progressHeader}>
          <Text style={[styles.progressTitle, darkMode && styles.textOnDark]}>Overall Progress</Text>
          <Text style={styles.progressPercent}>25%</Text>
        </View>
        <View style={[styles.progressTrack, darkMode && styles.trackDark]}>
          <View style={styles.progressFill} />
        </View>
        <Text style={[styles.progressNote, darkMode && styles.textMutedDark]}>1 of 4 areas completed</Text>
      </View>
    </ScrollView>
  );
}

function WorldScreen({ onStart }: { onStart: () => void }) {
  return <LandingScreen onStart={onStart} />;
}

function SettingsScreen({
  avatar,
  darkMode,
  draftName,
  editingName,
  grade,
  language,
  notifications,
  showAbout,
  showLanguageChoices,
  soundEffects,
  username,
  onCancelName,
  onChangeAvatar,
  onChangeDraftName,
  onCycleGrade,
  onEditName,
  onSaveName,
  onSelectLanguage,
  onToggleAbout,
  onToggleDark,
  onToggleLanguageChoices,
  onToggleNotifications,
  onToggleSound,
}: {
  avatar: (typeof avatarOptions)[number];
  darkMode: boolean;
  draftName: string;
  editingName: boolean;
  grade: number;
  language: "English" | "Filipino";
  notifications: boolean;
  showAbout: boolean;
  showLanguageChoices: boolean;
  soundEffects: boolean;
  username: string;
  onCancelName: () => void;
  onChangeAvatar: () => void;
  onChangeDraftName: (value: string) => void;
  onCycleGrade: () => void;
  onEditName: () => void;
  onSaveName: () => void;
  onSelectLanguage: (language: "English" | "Filipino") => void;
  onToggleAbout: () => void;
  onToggleDark: (value: boolean) => void;
  onToggleLanguageChoices: () => void;
  onToggleNotifications: (value: boolean) => void;
  onToggleSound: (value: boolean) => void;
}) {
  return (
    <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
      <SettingsProfileHeader avatar={avatar} darkMode={darkMode} grade={grade} username={username} />

      <Text style={[styles.settingsSectionLabel, darkMode && styles.textMutedDark]}>PROFILE</Text>
      <View style={[styles.settingsGroup, darkMode && styles.cardDark]}>
        <SettingsRow
          darkMode={darkMode}
          label="Edit Username"
          marker="U"
          value={editingName ? "Editing" : undefined}
          onPress={onEditName}
        />
        {editingName ? (
          <View style={styles.nameEditor}>
            <TextInput
              autoCapitalize="words"
              onChangeText={onChangeDraftName}
              placeholder="Trainer name"
              placeholderTextColor="#90a4b8"
              style={[styles.nameInput, darkMode && styles.nameInputDark]}
              value={draftName}
            />
            <View style={styles.editorActions}>
              <Pressable onPress={onCancelName} style={styles.editorGhostButton}>
                <Text style={styles.editorGhostText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={onSaveName} style={styles.editorSaveButton}>
                <Text style={styles.editorSaveText}>Save</Text>
              </Pressable>
            </View>
          </View>
        ) : null}
        <SettingsRow darkMode={darkMode} label="Change Avatar" marker="A" onPress={onChangeAvatar} />
        <SettingsRow
          darkMode={darkMode}
          label="Grade Level"
          marker="G"
          value={`Grade ${grade}`}
          onPress={onCycleGrade}
          isLast
        />
      </View>

      <Text style={[styles.settingsSectionLabel, darkMode && styles.textMutedDark]}>PREFERENCES</Text>
      <View style={[styles.settingsGroup, darkMode && styles.cardDark]}>
        <ToggleRow
          darkMode={darkMode}
          label="Sound Effects"
          marker="S"
          value={soundEffects}
          onValueChange={onToggleSound}
        />
        <ToggleRow
          darkMode={darkMode}
          label="Dark Mode"
          marker="D"
          value={darkMode}
          onValueChange={onToggleDark}
        />
        <ToggleRow
          darkMode={darkMode}
          label="Notifications"
          marker="N"
          value={notifications}
          onValueChange={onToggleNotifications}
          isLast
        />
      </View>

      <Text style={[styles.settingsSectionLabel, darkMode && styles.textMutedDark]}>APP</Text>
      <View style={[styles.settingsGroup, darkMode && styles.cardDark]}>
        <SettingsRow
          darkMode={darkMode}
          icon="language-outline"
          label="Language"
          value={language}
          onPress={onToggleLanguageChoices}
        />
        {showLanguageChoices ? (
          <View style={styles.languageChoices}>
            <ChoiceButton
              active={language === "English"}
              darkMode={darkMode}
              label="English"
              onPress={() => onSelectLanguage("English")}
            />
            <ChoiceButton
              active={language === "Filipino"}
              darkMode={darkMode}
              label="Filipino"
              onPress={() => onSelectLanguage("Filipino")}
            />
          </View>
        ) : null}
        <SettingsRow
          darkMode={darkMode}
          icon="information-circle-outline"
          label="About"
          onPress={onToggleAbout}
          isLast={!showAbout}
        />
        {showAbout ? (
          <View style={[styles.aboutPanel, darkMode && styles.aboutPanelDark]}>
            <Text style={[styles.aboutTitle, darkMode && styles.textOnDark]}>About TAKO MathQuest AI</Text>
            <Text style={[styles.aboutCopy, darkMode && styles.textMutedDark]}>
              TAKO is a prototype learning adventure for story-driven math practice, grade routes, and future
              AI-guided explanations in English and Filipino.
            </Text>
            <Text style={[styles.aboutMeta, darkMode && styles.textMutedDark]}>Version 1.0.0 - Prototype</Text>
          </View>
        ) : null}
      </View>

      <Pressable style={({ pressed }) => [styles.logoutButton, pressed && styles.pressed]}>
        <Text style={styles.logoutText}>Log Out</Text>
      </Pressable>
    </ScrollView>
  );
}

function SettingsProfileHeader({
  avatar,
  darkMode,
  grade,
  username,
}: {
  avatar: (typeof avatarOptions)[number];
  darkMode: boolean;
  grade: number;
  username: string;
}) {
  return (
    <View style={[styles.settingsHero, darkMode && styles.settingsHeroDark]}>
      <View style={styles.settingsHeroBand} />
      <View style={styles.settingsHeroBody}>
        <View style={styles.settingsAvatarLift}>
          <PixelAvatar avatar={avatar} size={72} framed />
        </View>
        <Text style={[styles.settingsHeroName, darkMode && styles.textOnDark]}>{username}</Text>
        <Text style={[styles.settingsHeroMeta, darkMode && styles.textMutedDark]}>
          Volcano Highlands - Grade {grade}
        </Text>
        <View style={styles.heroStats}>
          <MiniStat value="340" label="XP" />
          <MiniStat value="210" label="Coins" />
          <MiniStat value="3" label="Wins" />
        </View>
      </View>
    </View>
  );
}

function PixelAvatar({
  avatar,
  framed,
  size,
}: {
  avatar: (typeof avatarOptions)[number];
  framed?: boolean;
  size: number;
}) {
  return (
    <View
      style={[
        styles.avatarFrame,
        {
          width: size,
          height: size,
          borderRadius: Math.round(size * 0.28),
          backgroundColor: avatar.bg,
          borderWidth: framed ? 4 : 0,
        },
      ]}
    >
      <View
        style={[
          styles.pixelBody,
          {
            width: Math.round(size * 0.48),
            height: Math.round(size * 0.46),
            backgroundColor: avatar.body,
          },
        ]}
      >
        <View style={[styles.pixelAntenna, { backgroundColor: avatar.body }]} />
        <View style={styles.pixelEyes}>
          <View style={[styles.pixelEye, { backgroundColor: avatar.accent }]} />
          <View style={[styles.pixelEye, { backgroundColor: avatar.accent }]} />
        </View>
        <View style={[styles.pixelMouth, { backgroundColor: avatar.accent }]} />
      </View>
    </View>
  );
}

function ActionButton({
  label,
  marker,
  onPress,
  tone,
}: {
  label: string;
  marker: string;
  onPress: () => void;
  tone: "yellow" | "green" | "blue" | "purple";
}) {
  const toneStyle = {
    yellow: styles.actionYellow,
    green: styles.actionGreen,
    blue: styles.actionBlue,
    purple: styles.actionPurple,
  }[tone];

  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.actionButton, toneStyle, pressed && styles.pressed]}>
      <View style={styles.actionMarker}>
        <Text style={styles.actionMarkerText}>{marker}</Text>
      </View>
      <Text style={styles.actionLabel}>{label}</Text>
    </Pressable>
  );
}

function StatCard({
  darkMode,
  label,
  marker,
  tone,
  value,
}: {
  darkMode: boolean;
  label: string;
  marker: string;
  tone: string;
  value: string;
}) {
  return (
    <View style={[styles.statCard, darkMode && styles.cardDark]}>
      <Text style={[styles.statMarker, { color: tone }]}>{marker}</Text>
      <Text style={[styles.statValue, darkMode && styles.textOnDark]}>{value}</Text>
      <Text style={[styles.statLabel, darkMode && styles.textMutedDark]}>{label}</Text>
    </View>
  );
}

function SettingsRow({
  darkMode,
  icon,
  isLast,
  label,
  marker,
  onPress,
  value,
}: {
  darkMode: boolean;
  icon?: TabIcon;
  isLast?: boolean;
  label: string;
  marker?: string;
  onPress?: () => void;
  value?: string;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.settingsRow, isLast && styles.lastRow, pressed && styles.pressed]}>
      <View style={[styles.settingsMarker, darkMode && styles.settingsMarkerDark]}>
        {icon ? (
          <Ionicons name={icon} size={15} color="#54748d" />
        ) : (
          <Text style={styles.settingsMarkerText}>{marker}</Text>
        )}
      </View>
      <Text style={[styles.settingsLabel, darkMode && styles.textOnDark]}>{label}</Text>
      {value ? <Text style={[styles.settingsValue, darkMode && styles.textMutedDark]}>{value}</Text> : null}
      <Text style={[styles.chevron, darkMode && styles.textMutedDark]}>{">"}</Text>
    </Pressable>
  );
}

function ChoiceButton({
  active,
  darkMode,
  label,
  onPress,
}: {
  active: boolean;
  darkMode: boolean;
  label: "English" | "Filipino";
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.choiceButton,
        darkMode && styles.choiceButtonDark,
        active && styles.choiceButtonActive,
        pressed && styles.pressed,
      ]}
    >
      <Text style={[styles.choiceText, darkMode && styles.textMutedDark, active && styles.choiceTextActive]}>
        {label}
      </Text>
      {active ? <Ionicons name="checkmark-circle" size={18} color="#ff7d00" /> : null}
    </Pressable>
  );
}

function ToggleRow({
  darkMode,
  isLast,
  label,
  marker,
  onValueChange,
  value,
}: {
  darkMode: boolean;
  isLast?: boolean;
  label: string;
  marker: string;
  onValueChange: (value: boolean) => void;
  value: boolean;
}) {
  return (
    <View style={[styles.settingsRow, isLast && styles.lastRow]}>
      <View style={[styles.settingsMarker, darkMode && styles.settingsMarkerDark]}>
        <Text style={styles.settingsMarkerText}>{marker}</Text>
      </View>
      <Text style={[styles.settingsLabel, darkMode && styles.textOnDark]}>{label}</Text>
      <Switch
        onValueChange={onValueChange}
        thumbColor={value ? "#ffffff" : "#f7f9fb"}
        trackColor={{ false: "#b7c3cc", true: "#f6b900" }}
        value={value}
      />
    </View>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.miniStat}>
      <Text style={styles.miniStatValue}>{value}</Text>
      <Text style={styles.miniStatLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  app: {
    flex: 1,
    backgroundColor: "#f3f6fa",
  },
  appDark: {
    backgroundColor: "#101924",
  },
  statusBar: {
    height: 42,
    paddingHorizontal: 22,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  statusTime: {
    color: "#0d1c32",
    fontSize: 13,
    fontWeight: "800",
  },
  statusIcons: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  signalBars: {
    width: 13,
    height: 10,
    borderLeftWidth: 3,
    borderBottomWidth: 3,
    borderColor: "#203246",
  },
  signalBarsSmall: {
    width: 11,
    height: 8,
    borderTopWidth: 2,
    borderColor: "#203246",
    borderRadius: 4,
  },
  battery: {
    width: 19,
    height: 10,
    borderWidth: 2,
    borderColor: "#203246",
    borderRadius: 3,
    backgroundColor: "#203246",
  },
  batteryDark: {
    borderColor: "#d9e5ee",
    backgroundColor: "#d9e5ee",
  },
  statusPale: {
    borderColor: "#d9e5ee",
  },
  content: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 18,
    paddingBottom: 28,
    gap: 14,
  },
  homeHeader: {
    paddingTop: 8,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  greeting: {
    color: "#172338",
    fontSize: 24,
    lineHeight: 30,
    fontWeight: "900",
  },
  subtleText: {
    color: "#5f7890",
    fontSize: 13,
    lineHeight: 19,
    fontWeight: "500",
  },
  textOnDark: {
    color: "#f5f8fb",
  },
  textMutedDark: {
    color: "#a8bdcf",
  },
  notificationButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#edf2f6",
  },
  notificationDark: {
    backgroundColor: "#243548",
  },
  notificationText: {
    color: "#26384a",
    fontSize: 18,
    fontWeight: "900",
  },
  notificationDot: {
    position: "absolute",
    top: 6,
    right: 7,
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: "#ef4444",
  },
  profileCard: {
    minHeight: 132,
    borderRadius: 16,
    padding: 16,
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
    backgroundColor: "#30424c",
    shadowColor: "#000",
    shadowOpacity: 0.16,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 10 },
    elevation: 5,
  },
  avatarFrame: {
    alignItems: "center",
    justifyContent: "center",
    borderColor: "#ffffff",
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 5 },
  },
  pixelBody: {
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 6,
  },
  pixelAntenna: {
    position: "absolute",
    top: -6,
    width: 8,
    height: 8,
    borderRadius: 2,
  },
  pixelEyes: {
    flexDirection: "row",
    gap: 8,
    marginTop: 2,
  },
  pixelEye: {
    width: 5,
    height: 5,
    borderRadius: 1,
  },
  pixelMouth: {
    width: 14,
    height: 4,
    borderRadius: 2,
    marginTop: 8,
  },
  profileCardInfo: {
    flex: 1,
    gap: 7,
  },
  profileTitleRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  profileName: {
    flexShrink: 1,
    color: "#ffffff",
    fontSize: 18,
    lineHeight: 22,
    fontWeight: "900",
  },
  gradeChip: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 999,
    backgroundColor: "#f3c318",
  },
  gradeChipText: {
    color: "#3b3100",
    fontSize: 10,
    fontWeight: "900",
  },
  profileRegion: {
    color: "#cbd6de",
    fontSize: 12,
    fontWeight: "600",
  },
  xpTrack: {
    height: 6,
    borderRadius: 999,
    backgroundColor: "#dbe3e8",
    overflow: "hidden",
  },
  xpFill: {
    width: "68%",
    height: "100%",
    backgroundColor: "#ffc400",
  },
  profileMetric: {
    alignSelf: "flex-end",
    color: "#b8d2e8",
    fontSize: 11,
    fontWeight: "700",
  },
  sectionTitle: {
    marginTop: 2,
    color: "#172338",
    fontSize: 17,
    fontWeight: "900",
  },
  actionGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  actionButton: {
    width: "48.8%",
    minHeight: 42,
    borderRadius: 21,
    paddingHorizontal: 12,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    shadowColor: "#000",
    shadowOpacity: 0.12,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 5 },
    elevation: 3,
  },
  actionYellow: {
    backgroundColor: "#ffd34d",
  },
  actionGreen: {
    backgroundColor: "#4db250",
  },
  actionBlue: {
    backgroundColor: "#47a6e8",
  },
  actionPurple: {
    backgroundColor: "#ad47c7",
  },
  actionMarker: {
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.32)",
  },
  actionMarkerText: {
    color: "#132135",
    fontSize: 12,
    fontWeight: "900",
  },
  actionLabel: {
    flex: 1,
    color: "#ffffff",
    fontSize: 12,
    fontWeight: "900",
  },
  statsGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
  },
  statCard: {
    width: "48.4%",
    minHeight: 92,
    borderRadius: 16,
    padding: 14,
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#dfe6ed",
    shadowColor: "#000",
    shadowOpacity: 0.1,
    shadowRadius: 7,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  cardDark: {
    backgroundColor: "#172434",
    borderColor: "#2a3b4d",
  },
  statMarker: {
    fontSize: 13,
    fontWeight: "900",
  },
  statValue: {
    marginTop: 8,
    color: "#172338",
    fontSize: 23,
    lineHeight: 25,
    fontWeight: "900",
  },
  statLabel: {
    color: "#6c8399",
    fontSize: 10,
    lineHeight: 14,
    fontWeight: "600",
  },
  progressCard: {
    marginTop: 2,
    borderRadius: 16,
    padding: 14,
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#dfe6ed",
    shadowColor: "#000",
    shadowOpacity: 0.1,
    shadowRadius: 7,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  progressHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  progressTitle: {
    color: "#172338",
    fontSize: 14,
    fontWeight: "900",
  },
  progressPercent: {
    color: "#f2b400",
    fontSize: 13,
    fontWeight: "900",
  },
  progressTrack: {
    height: 10,
    borderRadius: 999,
    marginTop: 10,
    backgroundColor: "#e8edf1",
    overflow: "hidden",
  },
  trackDark: {
    backgroundColor: "#26384b",
  },
  progressFill: {
    width: "25%",
    height: "100%",
    borderRadius: 999,
    backgroundColor: "#ffbd00",
  },
  progressNote: {
    marginTop: 7,
    color: "#6a8399",
    fontSize: 10,
    fontWeight: "600",
  },
  pageHeader: {
    paddingTop: 8,
    gap: 4,
  },
  pageTitle: {
    color: "#172338",
    fontSize: 27,
    lineHeight: 32,
    fontWeight: "900",
  },
  worldMap: {
    aspectRatio: 16 / 9,
    borderRadius: 18,
    overflow: "hidden",
    borderWidth: 4,
    borderColor: "#223246",
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 5,
  },
  mapSun: {
    position: "absolute",
    right: 25,
    top: 18,
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: "#ffd25f",
  },
  mapMountainOne: {
    position: "absolute",
    left: -12,
    bottom: 39,
    width: 160,
    height: 84,
    borderTopLeftRadius: 70,
    borderTopRightRadius: 70,
    backgroundColor: "#31556b",
    transform: [{ rotate: "-8deg" }],
  },
  mapMountainTwo: {
    position: "absolute",
    right: -18,
    bottom: 48,
    width: 186,
    height: 90,
    borderTopLeftRadius: 80,
    borderTopRightRadius: 80,
    backgroundColor: "#24485f",
    transform: [{ rotate: "7deg" }],
  },
  mapRoad: {
    position: "absolute",
    left: "3%",
    right: "4%",
    bottom: 30,
    height: 18,
    borderRadius: 999,
    backgroundColor: "#e7d09b",
    transform: [{ rotate: "-5deg" }],
  },
  worldNode: {
    position: "absolute",
    width: 30,
    height: 30,
    borderRadius: 15,
    borderWidth: 3,
    alignItems: "center",
    justifyContent: "center",
  },
  worldNodeText: {
    color: "#3b2600",
    fontSize: 12,
    fontWeight: "900",
  },
  worldNodeLocked: {
    color: "#73879a",
  },
  worldPanel: {
    borderRadius: 16,
    padding: 16,
    gap: 16,
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#dfe6ed",
  },
  worldPanelTitle: {
    color: "#172338",
    fontSize: 18,
    fontWeight: "900",
  },
  worldPanelCopy: {
    marginTop: 4,
    color: "#617990",
    fontSize: 12,
    lineHeight: 18,
    fontWeight: "600",
  },
  worldProgressRow: {
    flexDirection: "row",
    gap: 10,
  },
  worldProgressPill: {
    flex: 1,
    borderRadius: 12,
    paddingVertical: 10,
    alignItems: "center",
    backgroundColor: "#eef3f7",
  },
  worldProgressValue: {
    color: "#172338",
    fontSize: 18,
    fontWeight: "900",
  },
  worldProgressLabel: {
    color: "#657f94",
    fontSize: 10,
    fontWeight: "700",
  },
  playButton: {
    minHeight: 70,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#ffbd20",
    borderWidth: 3,
    borderColor: "#ff7d00",
    shadowColor: "#000",
    shadowOpacity: 0.16,
    shadowRadius: 11,
    shadowOffset: { width: 0, height: 7 },
    elevation: 4,
  },
  playButtonReady: {
    backgroundColor: "#4db250",
    borderColor: "#258d38",
  },
  playButtonText: {
    color: "#211800",
    fontSize: 22,
    lineHeight: 25,
    fontWeight: "900",
  },
  playButtonSubtext: {
    color: "#3f3300",
    fontSize: 11,
    fontWeight: "800",
    marginTop: 3,
  },
  settingsHero: {
    marginHorizontal: -18,
    marginTop: -2,
    backgroundColor: "#f3f6fa",
  },
  settingsHeroDark: {
    backgroundColor: "#101924",
  },
  settingsHeroBand: {
    height: 112,
    backgroundColor: "#26384f",
  },
  settingsHeroBody: {
    alignItems: "center",
    paddingTop: 42,
    paddingBottom: 18,
  },
  settingsAvatarLift: {
    position: "absolute",
    top: -38,
  },
  settingsHeroName: {
    color: "#172338",
    fontSize: 21,
    lineHeight: 25,
    fontWeight: "900",
  },
  settingsHeroMeta: {
    marginTop: 4,
    color: "#5d7892",
    fontSize: 12,
    fontWeight: "600",
  },
  heroStats: {
    marginTop: 10,
    flexDirection: "row",
    gap: 12,
  },
  miniStat: {
    minWidth: 62,
    borderRadius: 18,
    paddingVertical: 8,
    alignItems: "center",
    backgroundColor: "#eef2f6",
  },
  miniStatValue: {
    color: "#122035",
    fontSize: 15,
    fontWeight: "900",
  },
  miniStatLabel: {
    color: "#6d8399",
    fontSize: 9,
    fontWeight: "700",
  },
  settingsSectionLabel: {
    marginTop: 2,
    color: "#49677f",
    fontSize: 11,
    fontWeight: "900",
    letterSpacing: 1.4,
  },
  settingsGroup: {
    borderRadius: 18,
    overflow: "hidden",
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#dce4eb",
    shadowColor: "#000",
    shadowOpacity: 0.08,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 3 },
    elevation: 2,
  },
  settingsRow: {
    minHeight: 54,
    paddingHorizontal: 15,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#dfe6ed",
  },
  lastRow: {
    borderBottomWidth: 0,
  },
  settingsMarker: {
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#eef4f8",
  },
  settingsMarkerDark: {
    backgroundColor: "#213246",
  },
  settingsMarkerText: {
    color: "#54748d",
    fontSize: 10,
    fontWeight: "900",
  },
  settingsLabel: {
    flex: 1,
    color: "#112139",
    fontSize: 13,
    fontWeight: "800",
  },
  settingsValue: {
    color: "#5d7892",
    fontSize: 11,
    fontWeight: "700",
  },
  languageChoices: {
    paddingHorizontal: 15,
    paddingBottom: 12,
    gap: 8,
    borderBottomWidth: 1,
    borderBottomColor: "#dfe6ed",
  },
  choiceButton: {
    minHeight: 42,
    borderRadius: 12,
    paddingHorizontal: 12,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: "#eef3f7",
    borderWidth: 1,
    borderColor: "#d7e0e8",
  },
  choiceButtonDark: {
    backgroundColor: "#213246",
    borderColor: "#31465b",
  },
  choiceButtonActive: {
    backgroundColor: "#fff4d4",
    borderColor: "#ffbd20",
  },
  choiceText: {
    color: "#526d85",
    fontSize: 13,
    fontWeight: "900",
  },
  choiceTextActive: {
    color: "#1d2638",
  },
  aboutPanel: {
    paddingHorizontal: 15,
    paddingTop: 2,
    paddingBottom: 15,
    gap: 6,
  },
  aboutPanelDark: {
    backgroundColor: "#172434",
  },
  aboutTitle: {
    color: "#172338",
    fontSize: 14,
    fontWeight: "900",
  },
  aboutCopy: {
    color: "#617990",
    fontSize: 12,
    lineHeight: 18,
    fontWeight: "600",
  },
  aboutMeta: {
    color: "#7b91a4",
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 0.7,
  },
  chevron: {
    color: "#6c879d",
    fontSize: 16,
    fontWeight: "800",
  },
  nameEditor: {
    paddingHorizontal: 15,
    paddingBottom: 14,
    gap: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#dfe6ed",
  },
  nameInput: {
    minHeight: 44,
    borderRadius: 12,
    paddingHorizontal: 12,
    color: "#172338",
    backgroundColor: "#eef3f7",
    borderWidth: 1,
    borderColor: "#d7e0e8",
    fontSize: 14,
    fontWeight: "700",
  },
  nameInputDark: {
    color: "#f5f8fb",
    backgroundColor: "#213246",
    borderColor: "#31465b",
  },
  editorActions: {
    flexDirection: "row",
    justifyContent: "flex-end",
    gap: 8,
  },
  editorGhostButton: {
    minWidth: 74,
    borderRadius: 12,
    paddingVertical: 9,
    alignItems: "center",
    backgroundColor: "#eef3f7",
  },
  editorGhostText: {
    color: "#526d85",
    fontSize: 12,
    fontWeight: "900",
  },
  editorSaveButton: {
    minWidth: 74,
    borderRadius: 12,
    paddingVertical: 9,
    alignItems: "center",
    backgroundColor: "#ffbd20",
  },
  editorSaveText: {
    color: "#241900",
    fontSize: 12,
    fontWeight: "900",
  },
  logoutButton: {
    minHeight: 52,
    borderRadius: 18,
    borderWidth: 2,
    borderColor: "#ffaaa7",
    alignItems: "center",
    justifyContent: "center",
  },
  logoutText: {
    color: "#ff514f",
    fontSize: 14,
    fontWeight: "900",
  },
  tabBar: {
    minHeight: 76,
    paddingTop: 8,
    paddingHorizontal: 16,
    paddingBottom: 10,
    flexDirection: "row",
    justifyContent: "space-between",
    backgroundColor: "#ffffff",
    borderTopWidth: 1,
    borderTopColor: "#dde6ee",
  },
  tabBarDark: {
    backgroundColor: "#111d2b",
    borderTopColor: "#27384a",
  },
  tabButton: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: 4,
    borderRadius: 14,
  },
  tabButtonActive: {
    backgroundColor: "#fff4d4",
  },
  tabMarker: {
    width: 24,
    height: 24,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: "#8aa0bd",
  },
  tabMarkerActive: {
    borderColor: "#ff6b00",
    backgroundColor: "#ff6b00",
  },
  tabMarkerText: {
    color: "#8aa0bd",
    fontSize: 11,
    fontWeight: "900",
  },
  tabMarkerTextActive: {
    color: "#ffffff",
  },
  tabLabel: {
    color: "#8aa0bd",
    fontSize: 10,
    fontWeight: "800",
  },
  tabLabelActive: {
    color: "#ff6b00",
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.98 }],
  },
});
