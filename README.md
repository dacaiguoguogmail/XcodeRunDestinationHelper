# XcodeRunDestinationHelper
Xcode Run Destination Helper

## 1.模拟器配置

### 1、ShowSingleTouches true //显示触摸的小圆圈

### 2、AllowFullscreenMode true //允许全屏、可以与Xcode分屏
![splitWindow](https://raw.githubusercontent.com/dacaiguoguogmail/XcodeRunDestinationHelper/master/splitWindow.png)

### 3、simulator color #c0c0c0 //边框颜色
![sliver](https://raw.githubusercontent.com/dacaiguoguogmail/XcodeRunDestinationHelper/master/sliver.png)

### 4、delete unavailable simulator //删除不可用的模拟器

### 5、清理运行目标列表。可修改代码保留某个
```
NSSet *keepSet = [NSSet setWithObjects:@"iPhone XR", nil];
```
![DestinationList](https://raw.githubusercontent.com/dacaiguoguogmail/XcodeRunDestinationHelper/master/DestinationList.png)

### 下载、按需修改、编译、运行、重启Xcode和模拟器即可

### fit Xcode 16

1. 导出 Xcode 配置：
   ```bash
   defaults export com.apple.dt.Xcode xxcode162.plist
   plutil -convert xml1 xxcode162.plist -o xxcode162.plist
   ```

2. 在 `DVTDeviceVisibilityPreferences` 中发现变化：
   ```xml
   <key>D46E1070-7032-427D-AE6C-45AD9E8FB72B</key>
   <false/>
   ```
   变成了
   ```xml
   <key>D46E1070-7032-427D-AE6C-45AD9E8FB72B</key>
   <integer>2</integer>
   ```

3. 值的含义：
   - `false` 代表 automatic
   - `1` 代表 always
   - `2` 代表 never
