# 🎨 App Theme System

## 🚀 **Change Your App's Colors in ONE LINE!**

### **Quick Theme Switch:**
Open `lib/theme/app_theme.dart` and change this line:

```dart
// ===== CHANGE THIS ONE LINE TO SWITCH THEMES =====
static const ThemeMode _currentTheme = ThemeMode.blue;
// =================================================
```

**Available Themes:**
- `ThemeMode.blue` - Professional blue theme (default)
- `ThemeMode.pink` - Vibrant pink theme
- `ThemeMode.red` - Bold red theme
- `ThemeMode.green` - Fresh green theme
- `ThemeMode.purple` - Royal purple theme
- `ThemeMode.orange` - Warm orange theme
- `ThemeMode.modern` - Clean white/light gray with blue secondary and pink accent

### **Example: Switch to Pink Theme**
```dart
static const ThemeMode _currentTheme = ThemeMode.pink;
```

### **What Gets Updated Automatically:**
✅ **All screens** - Backgrounds, text, buttons  
✅ **Navigation bars** - Colors, active states  
✅ **Cards & containers** - Borders, shadows  
✅ **Buttons** - Primary, secondary, outlined  
✅ **Text** - Headlines, body, secondary  
✅ **Shadows & overlays** - Consistent depth  
✅ **Splash screen** - Primary colors  

### **How It Works:**
1. **Centralized colors** in `AppTheme.colors`
2. **Automatic propagation** through Material theme
3. **Consistent styling** across all widgets
4. **Easy maintenance** - one file controls everything

### **Usage in Your Code:**
```dart
import 'package:bunny/theme/app_theme.dart';

// Use theme colors anywhere
Container(
  color: AppTheme.colors.primary,
  child: Text(
    'Hello World',
    style: TextStyle(color: AppTheme.colors.surface),
  ),
)
```

### **Theme Demo:**
Run the app and navigate to the theme demo screen to see all available themes in action!

---

**🎯 Pro Tip:** You can also create custom themes by adding new `ThemeMode` values and color schemes to the `_themes` map.
