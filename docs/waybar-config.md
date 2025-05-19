# Về lí do waybar tự reset config.jsonc và style.css mỗi lần khởi động hệ điều hành

## Nguyên nhân

- Mỗi lần mở máy, meowrch luôn chạy command này:

```exec-once = python $meowrch --action set-current-theme && python $meowrch --action set-wallpaper && waybar```

- Nguyên nhân nằm ở vế đầu tiên:

```exec-once = python $meowrch --action set-current-theme```

- Tiếp tục đào sâu vào câu lệnh này sẽ dẫn chúng ta đến file ```~/home/.config/meowrch/meowrch.py```. Ở đây chúng ta sẽ tìm thấy đoạn code liên quan đến ```--action set-current-theme```

```python
	elif args.action == "set-current-theme":
		theme_manager.set_current_theme
```

- Chúng ta nhận ra được nó được import từ 1 file khác: ```from utils.theming import ThemeManager```

- Đi đến ```utlis/theming.py```, ta sẽ thấy đoạn code:

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

## Vậy ```meowrch.py --action set-current-theme``` có làm gì?

- Thực chất nó gọi ```ThemeManager.set_current_theme()```
- Phương thức này gọi ```set_theme(self.current_theme)``` để apply theme đã lưu
- ```set_theme``` gọi lần lượt các ```option.apply(theme.name)``` từ ```theme_options```

## Tiếp tục tìm hiểu:

- TÌm đến ```utils/loader.py``` vì module ```theme_options``` được import từ đây.
- Ở đây ta có thể thấy các đoạn code liên quan:

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

### Đây là danh sách đối tượng khi cấu hình (CopyOption, WaybarCfgOption,...) tương ứng với từng thành phần sẽ được áp dụng khi đổi theme, bao gồm:

- ```hyprland-custom-prefs.conf```
- ```waybar.css```
- ```waybar.jsonc``` – có cờ ```reload=True```

### ```CopyOption``` – dùng cho các file chỉ cần chép qua

```python
@dataclass
class CopyOption(BaseOption):
	name: str
	path_to: str
	is_dir: bool = field(default=False)
```

- ```theme_name``` được dùng để tạo đường dẫn đến file trong thư mục theme: ```MEOWRCH_THEMES / theme_name / self.name```
- Nếu tồn tại file/folder đúng định dạng, sẽ copy sang ```self.path_to```

### ```WaybarCfgOption``` – xử lý riêng cho Waybar

```python
@dataclass
class WaybarCfgOption(BaseOption):
	name: str
	path_to: str
	reload: bool
```

- Cũng copy file tương ứng từ theme sang folder config của waybar ```(~/.config/waybar/config.jsonc)```
- Nếu ```reload=True``` và ```waybar``` đang chạy:

```bash
pkill -SIGUSR2 waybar
```

=> Gửi tín hiệu reload cấu hình (Waybar hỗ trợ reload bằng SIGUSR2)

- ```meowrch``` đang tự động áp theme khi khởi động, và trong đó nó copy đè lại ```waybar/config.jsonc``` và ```style.css``` từ thư mục theme.

## Tóm lại

Khi ```set_theme()``` được gọi với một ```theme_name```, nó sẽ tự động copy lại ```config.jsonc``` và ```style.css``` từ thư mục theme tương ứng, ghi đè mọi thứ đã chỉnh trong ```~/.config/waybar/config.jsonc``` và ```~/.config/waybar/style.css```

## Cách giải quyết

### Cách 1 (hiệu quả nhất): Sửa trực tiếp trong theme

- Sửa trực tiếp 2 file ```waybar.css``` và ```waybar.jsonc``` trong thư mục ```~/.config/meowrch/themes/<theme_name>```

### Cách 2 (sẽ nghiên cứu thêm): Vô hiệu hóa set-current-theme khi khởi động

- Vào ```~/.config/hypr/hyprland.conf``` tách ```exec-once = python $meowrch --action set-current-theme && python $meowrch --action set-wallpaper && waybar``` thành 2 command riêng:

```bash
exec-once = python $meowrch --action set-current-theme
exec=once = python $meowrch --action set-wallpaper && waybar
```

- Rồi sau đó có thể tạm thời vô hiệu hóa dòng lệnh đầu tiên để nó không tự động thực hiện chuỗi hành động ghi đè file như tôi đã giải thích ở trên:

```bash
#exec-once = python $meowrch --action set-current-theme
exec=once = python $meowrch --action set-wallpaper && waybar
```

- Nhưng cách này đôi lúc có hiệu quả, đôi lúc thì không vì 2 file ```waybar/config.jsonc``` và ```waybar/style.css``` vẫn bị ghi đè không rõ lí do.
- Và cũng cần tìm hiểu xem ngoài việc ghi đè config waybar thì câu lệnh ```python $meowrch --action set-current-theme``` này còn có thể làm gì khác nữa.