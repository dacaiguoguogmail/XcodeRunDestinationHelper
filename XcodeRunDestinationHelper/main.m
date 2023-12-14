//
//  main.m
//  XcodeRunDestinationHelper
//
//  Created by dacaiguoguo on 2018/11/14.
//  Copyright © 2018 dacaiguoguo. All rights reserved.
//
// defaults export com.apple.dt.Xcode Downloads/xcodesim.plist
// DVTIgnoredDevices

@import Foundation;

/// 生存log文件路径
/// @param fileName 文件名
/// @param ext 后缀
NSString *logFilePathWithNameAndExt(NSString *fileName, NSString *ext) {
    NSString *logFileName = [NSString stringWithFormat:@"%@_%@.%@", [[NSProcessInfo processInfo] globallyUniqueString], [@"XcodeRunDestinationHelper_" stringByAppendingString:fileName], ext?:@""];
    NSString *logFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:logFileName];
    return logFilePath;
}


/// 生成plist文件路径
/// @param fileName plist文件名
NSString *plistFilePathWithName(NSString *fileName) {
    NSString *logFilePath = logFilePathWithNameAndExt(fileName, @"plist");
    return logFilePath;
}

/// 打印默认的模拟器列表
/// @param iOSVersion 类似iOS-13-1
void logDefaultDevices(NSString *iOSVersion) {
    NSString *device_setPath = [NSString stringWithFormat:@"%@/Library/Developer/CoreSimulator/Devices/device_set.plist", NSHomeDirectory()];
    NSMutableDictionary *device_setInfo = [NSMutableDictionary dictionaryWithContentsOfFile:device_setPath];
    NSDictionary *DefaultDevices = device_setInfo[@"DefaultDevices"];
    NSDictionary<NSString *, NSString *> *iOS_12_1 = DefaultDevices[[@"com.apple.CoreSimulator.SimRuntime." stringByAppendingString:iOSVersion]];
    [iOS_12_1 enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *devideItem = [NSString stringWithFormat:@"%@/Library/Developer/CoreSimulator/Devices/%@", NSHomeDirectory(), obj];
        printf("name: %s\npath:%s\n", [key componentsSeparatedByString:@"."].lastObject.UTF8String, devideItem.UTF8String);
    }];
}


/// 清理文件，并退出
/// @param status 退出状态码
/// @param pathArray 需要清理的文件路径的数组
void exitWithStatusAndPathArray(int status, NSArray<NSString *> *pathArray) {
    NSFileManager *fn = [NSFileManager defaultManager];
    [pathArray enumerateObjectsUsingBlock:^(NSString * _Nonnull aPath, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([fn fileExistsAtPath:aPath]) {
            [fn removeItemAtPath:aPath error:nil];
        }
    }];
    exit(status);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString *> *pathArray = [NSMutableArray array];
        int ret = 0;
        // TODO: xcodebuild -showsdks -json 获取 "platform" : "iphonesimulator" 的版本号 作为参数
        logDefaultDevices(@"iOS-17-2");
        NSString *simulatorPlistPath = plistFilePathWithName(@"iphonesimulator");
        [pathArray addObject:simulatorPlistPath];

        // 导出模拟器配置
        NSString *exportSimulatorDefaultsCommand = [NSString stringWithFormat:@"defaults export com.apple.iphonesimulator %@", simulatorPlistPath];
        ret = system(exportSimulatorDefaultsCommand.UTF8String);
        if (ret != 0) {
            exitWithStatusAndPathArray(ret, pathArray);
        }

        // 获取导出的模拟器配置
        NSMutableDictionary *simulatorPlistInfo = [NSMutableDictionary dictionaryWithContentsOfFile:simulatorPlistPath];
        // 显示单点触摸圆点
        simulatorPlistInfo[@"ShowSingleTouches"] = @(1);
        // 允许全屏显示模式
        simulatorPlistInfo[@"AllowFullscreenMode"] = @(1);

        // 设置模拟器边框颜色
        NSMutableDictionary<NSString *,NSMutableDictionary<NSString *, NSString *> *> *devicePreferences = simulatorPlistInfo[@"DevicePreferences"];
        [devicePreferences enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSMutableDictionary<NSString *,NSString *> *obj, BOOL *stop) {
            obj[@"ChromeTint"] = @"#22ca92"; //simulator color
        }];

        // 把修改过的模拟器配置写入文件
        NSString *newSimulatorPlistPath = plistFilePathWithName(@"newiphonesimulator");
        [pathArray addObject:newSimulatorPlistPath];
        [simulatorPlistInfo writeToFile:newSimulatorPlistPath atomically:YES];

        // 导入修改过的模拟器配置
        NSString *importSimulatorDefaultsCommand = [NSString stringWithFormat:@"defaults import com.apple.iphonesimulator %@", newSimulatorPlistPath];
        ret = system(importSimulatorDefaultsCommand.UTF8String);
        if (ret != 0) {
            exitWithStatusAndPathArray(ret, pathArray);
        }

        // 导出Xcode配置
        NSString *plistPath = plistFilePathWithName(@"xcodedefault");
        [pathArray addObject:plistPath];
        NSString *command = [NSString stringWithFormat:@"defaults export com.apple.dt.Xcode %@", plistPath];
        ret = system(command.UTF8String);
        if (ret != 0) {
            exitWithStatusAndPathArray(ret, pathArray);
        }

        // 删除不可用的模拟器
        ret = system("xcrun simctl delete unavailable");
        if (ret != 0) {
            exitWithStatusAndPathArray(ret, pathArray);
        }

        // 获取模拟器列表
        NSString *jsonPath = logFilePathWithNameAndExt(@"devices", @"json");
        [pathArray addObject:jsonPath];
        NSString *command2Json = [NSString stringWithFormat:@"xcrun simctl list -j > %@", jsonPath]; // 'xcrun xcdevice list' also ok
        ret = system(command2Json.UTF8String);
        if (ret != 0) {
            exitWithStatusAndPathArray(ret, pathArray);
        }
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        if (jsonData.length == 0) {
            exitWithStatusAndPathArray(ret, pathArray);
        }
        NSDictionary *simList = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
        NSMutableDictionary *plistInfo = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];

        // 获取要修改的，不显示为运行目标的数组，进行修改
        NSMutableArray *ignoreDeviceIdArray = plistInfo[@"DVTIgnoredDevices"];

        // 需要保留的、显示为运行目标的集合， 可以是名字，也可以是id
        NSSet *keepSet = [NSSet setWithObjects:@"iPhone 15 Pro", nil];
        // NSSet *keepSet = [NSSet setWithObjects:@"562D22B9-B952-415F-A2A8-197B4975FE01", nil];


        __block BOOL ignoreDevicesChanged = NO;
        // 修改忽略列表
        NSDictionary<NSString *, NSArray *> *allDevicesInfo = simList[@"devices"];
        [allDevicesInfo enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray<NSDictionary<NSString *, NSString *> *> * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> * _Nonnull obj2, NSUInteger idx2, BOOL * _Nonnull stop2) {
                NSString *udid = obj2[@"udid"];

                if ([keepSet containsObject:obj2[@"name"]] || [keepSet containsObject:udid]) {
                    if ([ignoreDeviceIdArray containsObject:udid]) {
                        [ignoreDeviceIdArray removeObject:udid];
                        ignoreDevicesChanged = YES;
                    }
                    // skip
                    NSLog(@"Keep Device:%@ udid:%@", obj2[@"name"], udid);
                } else if (![ignoreDeviceIdArray containsObject:udid]) {
                    NSLog(@"Add udid:%@", udid);
                    [ignoreDeviceIdArray addObject:udid];
                    ignoreDevicesChanged = YES;
                }
            }];
        }];

        // 如果忽略的模拟器列表没有修改就没必要导入了，只需要重启模拟器使设置生效即可
        if (!ignoreDevicesChanged) {
            NSLog(@"please restart Simulator");
            exitWithStatusAndPathArray(0, pathArray);
        }

        // 把修改后的Xcode配置导入
        NSString *newPlistPath = plistFilePathWithName(@"newxcodedefault");
        [pathArray addObject:newPlistPath];
        BOOL success = [plistInfo writeToFile:newPlistPath atomically:YES];
        assert(success);
        NSString *importXcodeCommand = [NSString stringWithFormat:@"defaults import com.apple.dt.Xcode %@", newPlistPath];
        ret = system(importXcodeCommand.UTF8String);
        NSLog(@"please restart Xcode & Simulator");
        exitWithStatusAndPathArray(ret, pathArray);
    }
    return 0;
}
