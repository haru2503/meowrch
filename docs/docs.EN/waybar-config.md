# Why waybar automatically resets config.jsonc and style.css every time the OS starts

## Cause

- Every time the computer boots, meowrch always runs this command:

```exec-once = python $meowrch --action set-current-theme && python $meowrch --action set-wallpaper && waybar```

- The cause lies in the first part:

```exec-once = python $meowrch --action set-current-theme```

- Digging deeper into this command leads us to the file ```~/home/.config/meowrch/meowrch.py```. Here, we find the code related to ```--action set-current-theme```

```python
    elif args.action == "set-current-theme":
        theme_manager.set_current_theme
```

- We see that it is imported from another file: ```from utils.theming import ThemeManager```

- Going to ```utils/theming.py```, we see the following code:

```python
    def set_theme(self, theme: Union[str, Theme]) -> None:
        ##==> Проверка входящих данных
        ##########################################
        if isinstance(theme, str):
            logging.debug(f"The process of installing the \"{theme}\" theme has begun")
            obj: Optional[Theme] = self.themes.get(theme, None)

            if obj is None:
                logging.error(f"[X] Theme named \"{theme.name}\" not found")
                return

            theme = obj

        elif isinstance(theme, Theme):
            logging.debug(f"The process of installing the \"{theme.name}\" theme has begun")
            
        ##==> Применение темы
        ##########################################
        for option in theme_options:
            try:
                option.apply(theme.name)
            except:
                logging.error(f"[X] Unknown error when applying the \"{option._id}\" config: {traceback.format_exc()}")

        self.current_theme = theme
        Config._set_theme(theme_name=theme.name)

        ##==> Устанавливаем подходящие обои
        ##########################################
        current_wallpaper = Config.get_current_wallpaper()
        if current_wallpaper is None or not Path(current_wallpaper).exists():
            self.set_random_wallpaper()
        else:
            if current_wallpaper not in [str(i) for i in self.current_theme.available_wallpapers]:
                self.set_random_wallpaper()

        logging.debug(f"The theme has been successfully installed: {theme.name}")

    def set_current_theme(self) -> None:
        logging.debug("The process of setting a current theme has begun")
        self.set_theme(self.current_theme)
```

## So what does ```meowrch.py --action set-current-theme``` do?

- In fact, it calls ```ThemeManager.set_current_theme()```
- This method calls ```set_theme(self.current_theme)``` to apply the saved theme
- ```set_theme``` sequentially calls each ```option.apply(theme.name)``` from ```theme_options```

## Continue to investigate:

- Go to ```utils/loader.py``` because the module ```theme_options``` is imported from here.
- Here you can see the related code:

```python
...
from utils.options import (
    CopyOption, CopyOrGenOption, TmuxCfgOption, GTKOption, FishOption, 
    WaybarCfgOption, KittyOption, DunstOption, CavaOption
)
...
theme_options: List[BaseOption] = [
    ...
    CopyOption(_id="waybar_css", name="waybar.css", path_to=HOME / ".config" / "waybar" / "style.css", xorg_needed=False),
    ...
    WaybarCfgOption(
    _id="waybar_cfg", 
    name="waybar.jsonc", 
    path_to=HOME / ".config" / "waybar" / "config.jsonc",
    reload=True
),
    ...
]
```

### This is a list of objects for configuration (CopyOption, WaybarCfgOption,...) corresponding to each component to be applied when changing the theme, including:

- ```hyprland-custom-prefs.conf```
- ```waybar.css```
- ```waybar.jsonc``` – with the flag ```reload=True```

### ```CopyOption``` – used for files that only need to be copied

```python
@dataclass
class CopyOption(BaseOption):
    name: str
    path_to: str
    is_dir: bool = field(default=False)
```

- ```theme_name``` is used to create the path to the file in the theme folder: ```MEOWRCH_THEMES / theme_name / self.name```
- If a file/folder with the correct format exists, it will be copied to ```self.path_to```

### ```WaybarCfgOption``` – special handling for Waybar

```python
@dataclass
class WaybarCfgOption(BaseOption):
    name: str
    path_to: str
    reload: bool
```

- Also copies the corresponding file from the theme to the waybar config folder ```(~/.config/waybar/config.jsonc)```
- If ```reload=True``` and ```waybar``` is running:

```bash
pkill -SIGUSR2 waybar
```

=> Sends a reload signal to waybar (Waybar supports reloading via SIGUSR2)

- ```meowrch``` is automatically applying the theme at startup, and in doing so, it overwrites ```waybar/config.jsonc``` and ```style.css``` from the theme folder.

## In summary

When ```set_theme()``` is called with a ```theme_name```, it will automatically copy ```config.jsonc``` and ```style.css``` from the corresponding theme folder, overwriting everything you have edited in ```~/.config/waybar/config.jsonc``` and ```~/.config/waybar/style.css```

## Solution

### Method 1 (most effective): Edit directly in the theme

- Directly edit the two files ```waybar.css``` and ```waybar.jsonc``` in the folder ```~/.config/meowrch/themes/<theme_name>```

### Method 2 (needs more research): Disable set-current-theme at startup

- Go to ```~/.config/hypr/hyprland.conf``` and split ```exec-once = python $meowrch --action set-current-theme && python $meowrch --action set-wallpaper && waybar``` into two separate commands:

```bash
exec-once = python $meowrch --action set-current-theme
exec=once = python $meowrch --action set-wallpaper && waybar
```

- Then you can temporarily disable the first command so it does not automatically perform the file overwriting actions as explained above:

```bash
#exec-once = python $meowrch --action set-current-theme
exec=once = python $meowrch --action set-wallpaper && waybar
```

- However, this method sometimes works, sometimes does not, because the two files ```waybar/config.jsonc``` and ```waybar/style.css``` are still overwritten for unclear reasons.
- Also, it is necessary to find out if, besides overwriting the waybar config, the command ```python $meowrch --action set-current-theme``` does anything else. 