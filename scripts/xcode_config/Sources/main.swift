import Foundation
import XcodeProj
import PathKit
let arguments = CommandLine.arguments
let projectPath = arguments.count > 1 ? arguments[1] : "example/ios/Runner.xcodeproj"
let project = try XcodeProj(path: Path(projectPath))
for configuration in project.pbxproj.buildConfigurations {
  configuration.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"
  configuration.buildSettings.removeValue(forKey: "DEVELOPMENT_TEAM")
}
// 模板把插件目录作为 Xcode 文件引用，会与 Flutter 自动生成的 SwiftPM 依赖重复覆盖。
let localReferences = project.pbxproj.fileReferences.filter { $0.path == "../../ios/delivery_photo_assist" }
for reference in localReferences {
  for group in project.pbxproj.groups { group.children.removeAll { $0 === reference } }
  project.pbxproj.delete(object: reference)
}
try project.write(path: Path(projectPath))
print("示例已设为 iOS 16，并清除个人签名团队配置。")
