# SCHED-1: Routine-Based Reminders for Dispensed

*Researched: 2026-03-13*

---

## 1. What existing apps do

The industry status quo is time-based, with routine labels as cosmetic sugar. No major medication app truly decouples reminders from clock time at the data layer. Instead, they use routine labels as a presentation layer on top of specific times.

**Medisafe** organises the day into four segments (morning, afternoon, evening, night) and lets users set different weekend times. During setup, you pick a specific clock time, and the app slots it into the appropriate segment. The home screen groups medications under these segment headers rather than showing raw times. This is the closest a mainstream app gets to routine-based display, but underneath it is still fully time-driven.

**Round Health** uses "reminder windows" rather than exact times. You set a window (e.g. 7am-9am) and the app sends three alerts across that window. It offers default windows labelled breakfast, lunch, dinner, and bedtime to speed setup. This is the most thoughtful implementation: it acknowledges that real life is not punctual and gives users a buffer. However, the underlying model is still a time range.

**MyTherapy** is strictly time-based. You set a clock time per dose and get a push notification. There is no routine-anchor concept. Scheduling is flexible (complex frequencies, injection site rotation) but always clock-pinned.

**CareClinic** is the one app that explicitly markets routine-anchoring. It lets users "connect doses with meals, sleep, or other habits." It also tracks sleep and nutrition, which gives it the data to know when those anchors actually happen. However, CareClinic is a comprehensive chronic illness tracker, not a focused medication reminder -- the feature sits inside a complex app.

**Mango Health** used gamification (points for on-time doses) but was fully time-based before it was discontinued.

**The pattern across the market:** Every app ultimately stores a clock time. The best ones (Medisafe, Round Health) present those times as routine labels or windows. None truly lets a user say "with breakfast" and then have the app wait for a signal that breakfast is happening. The opportunity for Dispensed is to make the routine anchor a first-class concept in the data model while still resolving to a practical notification time.

---

## 2. Data model implications

### Proposed changes

The key insight: routine anchors should sit alongside time_of_day, not replace it. Every dose must eventually resolve to a concrete `scheduled_for` datetime so that the dashboard, notifications, and dose generation all continue to work. The routine anchor provides the *meaning* ("with breakfast"); the resolved time provides the *mechanism*.

**Migration: add columns to `schedules`**

```ruby
add_column :schedules, :routine_anchor, :string  # null = pure clock-time
add_column :schedules, :food_relation, :string    # null, "with_food", "before_food", "after_food", "empty_stomach"
change_column_null :schedules, :time_of_day, true  # now nullable for routine-anchored schedules
```

**New columns explained:**

- **`routine_anchor`** (string, nullable): One of a fixed set of values. When null, this is a traditional clock-time schedule. When set, the schedule is routine-anchored and `time_of_day` becomes the *default resolved time* for that anchor rather than a hard requirement.
- **`food_relation`** (string, nullable): Structured version of what is currently buried in `instructions` free text. This has clinical significance (levothyroxine requires `empty_stomach`; metformin requires `with_food`) and should be a first-class field rather than free text.

**Routine anchor values for a UK context:**

| Anchor key | Display label | Default time | Default window |
|---|---|---|---|
| `waking` | When you wake up | 07:00 | 06:00 - 09:00 |
| `breakfast` | With breakfast | 08:00 | 07:00 - 10:00 |
| `midday` | Around midday | 12:00 | 11:00 - 14:00 |
| `evening_meal` | With your evening meal | 18:00 | 17:00 - 20:00 |
| `bedtime` | Before bed | 22:00 | 21:00 - 23:30 |

These five cover the vast majority of UK prescribing patterns. "Waking" is distinct from "breakfast" because many medications (levothyroxine, omeprazole) must be taken 30-60 minutes *before* food. "Midday" avoids the culturally ambiguous "lunch" vs "dinner" terminology that varies across UK regions.

### Interaction with GenerateDailyDosesJob

The job currently builds `scheduled_for` from `schedule.time_of_day`. With the new model:

```ruby
def resolve_time(schedule, date)
  if schedule.routine_anchor.present?
    base_time = schedule.time_of_day || ANCHOR_DEFAULTS[schedule.routine_anchor]
  else
    base_time = schedule.time_of_day
  end

  DateTime.new(date.year, date.month, date.day,
               base_time.hour, base_time.min, 0,
               Time.zone.formatted_offset)
end
```

The generated `Dose.scheduled_for` continues to be a concrete datetime. The routine anchor affects *display* and *notification windowing*, not the fundamental dose generation logic. All existing code that queries doses by `scheduled_for` continues to work unchanged.

---

## 3. UX design

### Schedule creation/edit flow

**Step 1: "When do you take this?"**

```
+----------------------------------+
|  When do you take [Metformin]?   |
|                                  |
|  +----------------------------+  |
|  |  With breakfast            |  |  <- large tap targets
|  +----------------------------+  |
|  +----------------------------+  |
|  |  Before bed                |  |
|  +----------------------------+  |
|  +----------------------------+  |
|  |  At a specific time        |  |  <- escape hatch to clock picker
|  +----------------------------+  |
|                                  |
|  More options v                  |  <- reveals: Waking, Midday, Evening meal
+----------------------------------+
```

"With breakfast" and "Before bed" are the two most common routine anchors and cover the majority of once-daily and twice-daily regimens. "At a specific time" is always available but is not the default path.

**Step 2: If routine anchor selected:**

```
+----------------------------------+
|  With breakfast                  |
|                                  |
|  We'll remind you around 8:00am |
|  You can adjust this:            |
|  +----------+                    |
|  |  08:00   |  <- time picker,   |
|  +----------+    pre-filled      |
|                                  |
|  With food?                      |
|  * With food                     |  <- pre-selected for breakfast
|  o Before food (empty stomach)   |
|  o Doesn't matter                |
|                                  |
|  Frequency: Daily v              |
|                                  |
|  [Save]                          |
+----------------------------------+
```

### Dashboard display

For routine-anchored schedules, the routine label is the primary text, time is secondary:

```
+---------------+
| With breakfast |
|   08:00       |
|               |
|  [Taken?]     |
+---------------+
```

### "Due now" logic

Routine-anchored doses get a wider window (~2 hours) instead of the current 60-minute slot, using hardcoded window sizes per anchor in the model.

---

## 4. Edge cases and risks

### Routines that vary (weekday vs weekend breakfast)

Allow per-schedule overrides for weekend timing using existing `days_of_week` system. User creates two schedules: weekdays (breakfast at 07:00) and weekends (breakfast at 09:00). The `no_overlapping_schedules` validation already handles this. Medisafe takes exactly this approach.

**MVP simplification:** Do not add special weekend UI. Existing "specific days" frequency already supports this.

### Medications with strict interval requirements (e.g. "every 8 hours")

Interval-based dosing is fundamentally incompatible with routine anchoring. Keep "At a specific time" as the path for these. For MVP, user picks the appropriate option.

### Clinical safety: medications with strict timing constraints

UK examples:
- **Levothyroxine**: 30-60 minutes before food, empty stomach, water only
- **Bisphosphonates (alendronic acid)**: 30 minutes before food, remain upright
- **PPIs (omeprazole, lansoprazole)**: 30-60 minutes before food
- **Metformin**: with or just after food
- **Statins (simvastatin)**: at night

**Approach -- layered safety, not hard blocks:**

1. **`food_relation` as structured data**: Moving "take with food" from free text to a structured field means the system can reason about it.
2. **Instructional banners, not locks**: Contextual warnings when anchor and food_relation conflict (e.g. breakfast + empty_stomach → suggest "When you wake up" instead).
3. **No automatic clinical inference in MVP**: food_relation set by user. Future: pre-populate from dm+d code.
4. **Never override clinical instructions**: Imported prescription text displayed verbatim alongside routine anchors.

---

## 5. MVP recommendation (SCHED-1a)

**One migration, three UI changes, no new models.**

### Migration

```ruby
class AddRoutineAnchorToSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :schedules, :routine_anchor, :string
    add_column :schedules, :food_relation, :string
    change_column_null :schedules, :time_of_day, true
  end
end
```

### Model constants (hardcoded windows, no extra columns)

```ruby
ROUTINE_ANCHORS = {
  "waking"       => { label: "When you wake up",       default_time: "07:00", window_minutes: 120 },
  "breakfast"    => { label: "With breakfast",          default_time: "08:00", window_minutes: 120 },
  "midday"       => { label: "Around midday",          default_time: "12:00", window_minutes: 120 },
  "evening_meal" => { label: "With your evening meal", default_time: "18:00", window_minutes: 120 },
  "bedtime"      => { label: "Before bed",             default_time: "22:00", window_minutes: 90  },
}.freeze

FOOD_RELATIONS = %w[with_food before_food after_food empty_stomach].freeze
```

### UI changes

1. **Schedule form**: "When do you take this?" as first field with routine anchor buttons above time picker
2. **Dashboard cells**: Show routine label as primary text when anchor is present
3. **Due-now logic**: Widen window for routine-anchored doses

### Deferred

- Per-anchor customisable windows (window_start/window_end columns)
- Weekend time overrides as specific UI feature
- Auto-detection of timing constraints from dm+d codes
- "I just had breakfast" signal
- Routine time learning from user behaviour patterns

---

## Sources

- Round Health -- iMedicalApps review
- CareClinic medication tracker features
- Medisafe -- how to use guide (techenhancedlife.com)
- ResearchGate: Don't Forget Your Pill -- designing apps for daily routines
- Levothyroxine timing -- PMC
- GoodRx medication reminder apps overview
- Medisafe app features (medisafeapp.com)
