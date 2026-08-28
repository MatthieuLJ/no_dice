# Project Overview & Architecture Guide: `No Dice`

`No Dice` is a mobile-first 3D physics polyhedral dice roller application built in **Godot 4** (GDScript). The app relies on physical accelerometer device tilt/shake inputs and realistic 3D rigid body dynamics to simulate rolling polyhedral dice (D4, D6, D8, D10, D12, D20, D100) inside a camera-bound enclosure.

---

The game uses specifically Godot 4.7 currently.

## Game Flow & Core User Experience

1. **Start Menu (`start_menu.tscn` / `start_menu.gd`)**:
   - The user selects which dice to roll from the polyhedral suite (D4, D6, D8, D10, D12, D20, D100).
   - The d100 is a composition of 2 d10, one for the tens and one for the units.
   - The regular d10 also has 2 designs, one going from 0 to 9 and another from 1 to 10.
   - Enforces a **maximum limit of 30 dice** to ensure mobile performance.
   - Tapping "Roll" or tapping anywhere outside the menu hides the menu and spawns the dice.

2. **3D Physics & Roll State (`world_physics.tscn` / `world_physics.gd`)**:
   - Dice roll dynamically in 3D inside the camera view frustum.
   - Real-time mobile accelerometer hardware inputs (`Input.get_accelerometer()`) map device tilt directly to simulated gravity in the 3D enclosure.
   - On desktop, Spacebar or directional keys apply calibrated physical roll impulses.
   - No artificial forces (acceleration or rotation) should ever be added, only "real" physics should be moving the dice.
   - **Locking Mechanics**: After at least one roll, tapping an individual stationary die toggles its locked state (`is_user_locked`). Locked dice freeze in place and display a soft, blurry 3D spatial glow highlight ([`shaders/lock_glow.gdshader`](no_dice/shaders/lock_glow.gdshader)).
   - **Dragging Mechanics**: Dragging a die translates it across the ground plane without re-triggering the result screen.

3. **Settlement & Result Screen (`result_screen.tscn` / `result_screen.gd`)**:
   - When all dice come to rest (`all_at_rest`), the game locks the dice and presents the Result Screen overlay after a short delay.
   - **Broken Die Detection**: If a die rests leaning or cocked on an edge (`is_flat == false` via normal dot-product), the result screen reports "BROKEN DIE" and displays a **Lock Flat & Reroll** button.
   - **Probability Statistics**: For flat rolls, displays the total sum, individual face breakdown, and exact Probability Mass Function ($P(\text{Sum} \ge X)$) drawn via [`histogram_drawer.gd`](no_dice/histogram_drawer.gd).
   - **Reroll / Continuation**:
	 - **Roll Again**: Hides the result screen and unlocks unlocked dice for another roll.
	 - **Lock Flat & Reroll**: Locks all dice currently resting flat and leaves cocked/leaning dice ready to re-roll.

---

## Directory & File Structure

```
no_dice/
├── base_die.gd             # Abstract Base Class (class_name BaseDie extends RigidBody3D)
├── die.tscn / die.gd       # Base die scene blueprint
├── d4.tscn / d4.gd         # D4 Tetrahedron die
├── d6.tscn / d6.gd         # D6 Hexahedron (Cube) die
├── d8.tscn / d8.gd         # D8 Octahedron die
├── d10.tscn / d10.gd       # D10 Pentagonal Trapezohedron die (low_0, high_10, tens modes)
├── d12.tscn / d12.gd       # D12 Dodecahedron die
├── d20.tscn / d20.gd       # D20 Icosahedron die
├── dice_config.gd          # Central physics tuning constants (Mass, Inertia, Damping, Friction)
├── world_physics.tscn/.gd  # Main 3D world controller, gravity, touch inputs, settlement logic
├── pyramid_scale.gd        # Camera frustum aspect ratio adapter for mobile screen sizes
├── start_menu.tscn/.gd     # Main Menu UI (dice selector, 30-dice cap)
├── result_screen.tscn/.gd  # Result overlay UI (sum calculation, PMF stats, broken die handling)
├── histogram_drawer.gd     # Canvas drawing control for PMF probability charts
├── debug_label.tscn/.gd    # Desktop/Mobile real-time telemetry overlay
├── project.godot           # Godot 4 project settings (120Hz physics ticks, mobile config)
├── export_presets.cfg      # Android export preset (com.matthieu.nodice)
├── shaders/
│   ├── lock_glow.gdshader # 3D spatial additive glow shader for locked die highlights
│   └── screen_blur.gdshader # Background gaussian blur glassmorphism shader
└── textures/               # Polyhedral face texture atlases (d4, d6, d8, d10, d12, d20)
```

---

## Core System Architecture

### 1. `BaseDie` Inheritance Hierarchy ([`base_die.gd`](no_dice/base_die.gd))
All polyhedral dice inherit from `BaseDie`:
* `ground` resolution in `_ready()`.
* **Viewport Frustum Boundary Clamping**: `_integrate_forces(state)` clamps position inside camera view bounds (`min_x`, `max_x`, `min_z`, `max_z`), applies zero-bounce one-way directional velocity guards (`maxf(0.0, ...)`, `minf(0.0, ...)`), and handles emergency out-of-bounds reset recovery.
* **Upward Face Detection**: Shared `get_upward_value()` dot-product face calculation comparing face normal against `ground.global_transform.basis.y`.

### 2. Physical Tuning Standards ([`dice_config.gd`](no_dice/dice_config.gd))
* **Physics Refresh Rate**: `120 Hz` (`physics/common/physics_ticks_per_second=120` in `project.godot`).
* **Size-Proportional Die Masses**:
  * **D4**: `0.005 kg` ($5.0\text{g}$)
  * **D6**: `0.006 kg` ($6.0\text{g}$)
  * **D8**: `0.0065 kg` ($6.5\text{g}$)
  * **D10**: `0.0075 kg` ($7.5\text{g}$)
  * **D12**: `0.0085 kg` ($8.5\text{g}$)
  * **D20**: `0.010 kg` ($10.0\text{g}$)
* **Rotational Inertia**: Scaled proportionally with mass ($I = m \cdot 0.016$, ranging from `Vector3(0.00008, 0.00008, 0.00008)` for D4 to `Vector3(0.00016, 0.00016, 0.00016)` for D20).
* **Damping, Friction & Restitution**: `LINEAR_DAMP = 0.15`, `ANGULAR_DAMP = 0.20`, `FRICTION = 0.60`, `BOUNCE = 0.35`.
* **Pure Physical Motion**: No artificial forces (acceleration or rotation) or fake shake thresholds. 100% driven by real 3D accelerometer inertial forces and Gyroscope Coriolis/Centrifugal forces.
* **Floor Contact**: `min_y = 0.0` allows Godot's 3D physics collision solver to handle floor contact naturally with full normal force ($F_N$), preventing micro-lifting air hockey sliding.

### 3. Dynamic Dice Scaling ($1 \le N \le 30$)
* **Count-Dependent Scaling**: Calculates linear scale factor via `DiceConfig.get_scale_for_count(N)`:
  * **$N = 1$ die**: **$2.5\times$ base size**.
  * **$N = 30$ dice**: **$1.0\times$ base size**.
* **Godot 4 Child Node Scaling**: Scales child `CollisionShape3D` and `MeshInstance3D` nodes directly (`col_shape.scale` / `mesh_inst.scale`) to preserve 3D physics solver compatibility.
* **Metadata Half-Size Detection**: `BaseDie._get_die_half_size()` reads stored `die_scale` metadata (`get_meta("die_scale", 1.0)`) so collision bounds scale accurately across all polyhedral classes (`D4`, `D6`, `D8`, `D10`, `D12`, `D20`).

### 4. Retro Arcade UI & Typography Design System
* **8-Bit Retro Font Integration**: Built with [`fonts/PressStart2P-Regular.ttf`](no_dice/fonts/PressStart2P-Regular.ttf) under SIL Open Font License 1.1 ([`fonts/OFL.txt`](no_dice/fonts/OFL.txt)). Applied across titles, config labels, count breakdowns, action buttons, and PMF canvas charts.
* **80% Screen Bounds**: Main Menu (`start_menu.tscn`) and Result Screen (`result_screen.tscn`) expand to 80% screen bounds ($880 \times 1400\text{px}$) with dark translucent glass containers (`Color(0.02, 0.08, 0.04, 0.9)`) and 4px neon green borders (`Color(0.2, 1.0, 0.4)`).
* **Tap-Outside Roll Dismissal**: Tapping anywhere outside the menu card dismisses the menu and triggers the roll.
* **Multiline Count Breakdown**: Automatically splits face counts across two lines in `result_screen.gd` when `count_parts.size() > 5`.

### 5. Shader System
* **Locked Die Aura ([`shaders/lock_glow.gdshader`](no_dice/shaders/lock_glow.gdshader))**: 3D spatial additive glow shader applied to `mesh_inst.material_overlay`. Uses `render_mode cull_front, unshaded, blend_add, depth_draw_never` to expand a soft, blurry golden aura around locked dice without obscuring front face textures.
* **Glassmorphism Blur ([`shaders/screen_blur.gdshader`](no_dice/shaders/screen_blur.gdshader))**: Background screen-space gaussian blur applied behind UI panels.

---

## Guidelines for Future Development

1. **Maintain Static Typing**: Always use explicit types for GDScript variables, parameters, and return types (`var speed: float = 200.0`, `func get_upward_value() -> Dictionary:`).
2. **Preserve `BaseDie` Inheritance**: Keep shared physics, clamping, boundary recovery, and ground resolution in `base_die.gd`. Derived die scripts should only specify geometry, texture building, and face tables.
3. **Verify Winding & Normals**: When creating polyhedral meshes, ensure vertices are constructed in Counter-Clockwise (CCW) 3D outward winding order so backface culling (`cull_back` / `cull_front`) functions properly.

---

## Tooling
1. To sign a release, I need to run  `"C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -keystore "C:\Users\djens\Android_keystore"
  "C:\Users\djens\Documents\no_dice\No_Dice.aab" YOUR_KEY_ALIAS`
