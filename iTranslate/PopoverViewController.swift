import Cocoa
import CommonCrypto
import UserNotifications
import Foundation
import GoogleReporter
import ServiceManagement

var state = 0  //开机启动状态，默认关闭
var newstate = 1  //软件启用状态，默认启用
var temp = ""
var tempTrans = ""
var from = "auto"
var to = "auto"


class PopoverViewController: NSViewController {
    @IBOutlet var settingsMenu: NSMenu!
    
    @IBOutlet weak var inputText: NSSearchField!
    @IBOutlet weak var translatedText: NSTextField!
    @IBOutlet weak var copyButton: NSButton!
    @IBOutlet weak var langSwicher: NSPopUpButtonCell!
    
    // 新增一个控制启用/关闭的选框
    @IBOutlet weak var turnSwitch: NSButton!
    // 原启用的控制菜单选项
    @IBOutlet weak var enableBootUp: NSMenuItem!
    
    
    
    // 软件启用按钮逻辑
    @IBAction func turnOnOff(_ sender: Any) {
        newstate = turnSwitch.state.rawValue
        if (newstate == 1) {
            turnSwitch.title = "启用"
        }
        else {
            turnSwitch.title = "关闭"
        }
        
        GoogleReporter.shared.event("弹窗", action: "启动软件", label: String(newstate)) //启用软件事件埋点
    }
    
    // 切换翻译语言的逻辑
    @IBAction func switchLanguage(_ sender: Any) {
        let selected = langSwicher.indexOfSelectedItem
        temp = ""
        tempTrans = ""
        switch selected {
        case 0:
            from = "auto"
            to = "auto"
        case 1:
            from = "auto"
            to = "zh"
            break
        case 2:
            from = "auto"
            to = "en"
            break
        default:
            from = "auto"
            to = "auto"
        }
    }
    
    // 弹出设置弹窗逻辑
    @IBAction func settingsButton(_ sender: Any) {
        let p = NSPoint(x: (sender as AnyObject).frame.width, y: 0)
        settingsMenu.popUp(positioning: nil, at: p, in: sender as? NSView)
        
        GoogleReporter.shared.event("弹窗", action: "打开弹窗") //打开弹窗事件埋点
    }
    
    // 设置快捷键
    @IBAction func setShortCut(_ sender: Any) {
//        let recordView = RecordView(frame: CGRect.zero)
//        recordView.tintColor = NSColor(red: 0.164, green: 0.517, blue: 0.823, alpha: 1)
//        let keyCombo = KeyCombo(doubledCocoaModifiers: .command)
//        recordView.keyCombo = keyCombo
        // 用通知提示
        notify(title: "功能提醒", body: "开发中")
        GoogleReporter.shared.event("弹窗", action: "设置快捷键") //设置快捷键事件埋点
    }
     
    
    // 退出软件逻辑
    @IBAction func quitApp(_ sender: Any) {
        NSApplication.shared.terminate(self)
        
        GoogleReporter.shared.event("弹窗", action: "退出软件") //退出软件事件埋点
    }
    
    // 开机启动逻辑
    @IBAction func enableTrans(_ sender: Any) {
        state = enableBootUp.state.rawValue
        if (state == 0) {
            enableBootUp.state = NSControl.StateValue.on
            notify(title: "开机自启动", body: "开启")
        }
        else {
            enableBootUp.state = NSControl.StateValue.off
            notify(title: "开机自启动", body: "关闭")
        }
        state = enableBootUp.state.rawValue
        
        startupAppWhenLogin(startup: true)
        
        GoogleReporter.shared.event("弹窗", action: "开机启动", label: String(state)) //开机启动的埋点事件
    }
    
    // 新增开机启动代码
    func startupAppWhenLogin(startup: Bool) {
        let launcherAppId = "com.tlang.LauncherTrans"
        //let runningApps = NSWorkspace.shared.runningApplications
        //let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        // 注册启动项
        SMLoginItemSetEnabled(launcherAppId as CFString, startup)

        if startup {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }
    
    // 搜索框逻辑
    @IBAction func searchClick(_ sender: NSSearchField) {
        copyButton.title = "复制"
        let cur = sender.stringValue;
        if (cur != temp){
            getTranslationResult(str: cur, type:"search")
            temp = cur
        }
        
        GoogleReporter.shared.event("弹窗", action: "输入搜索") //在弹窗中输入搜索的埋点事件
    }
    
    // 复制结果按钮的逻辑
    @IBAction func copyResult(_ sender: Any) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(tempTrans, forType: .string)
        copyButton.title = "已复制"
        
        GoogleReporter.shared.event("弹窗", action: "复制结果") //在弹窗中复制结果的埋点事件
    }
    
    // ？？？？貌似是程序加载部分的逻辑
    override func viewDidLoad() {
        super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(onPasteboardChanged), name: .NSPasteboardDidChange, object: nil)
    }
    
    @objc
    func onPasteboardChanged(_ notification: Notification) {
        guard let pb = notification.object as? NSPasteboard else { return }
        guard let items = pb.pasteboardItems else { return }
        
        guard let cur = items.first?.string(forType: .string) else { return }
        if (cur != temp && cur != tempTrans && newstate==1){
            inputText.stringValue = cur
            getTranslationResult(str: cur, type:"copy")
            temp = cur
        }
    }
    


    
    
    // 从百度翻译接口获取翻译结果
    func getTranslationResult(str:String, type:String) -> Void {
        if (str.isEmpty) {
            translatedText.stringValue = ""
//            labelTouchBar(str: "")
            return
        }
        
        let appid = "20200117000376242"; //百度翻译APPID
        let salt = "1435660288"; //其实应该是随机数的但是我太懒了
        let key = "L6Gr4G1h8xjJntY98FQe"; //百度翻译KEY
        let sign = md5Hash(str: appid+str+salt+key);
        let base = "https://fanyi-api.baidu.com/api/trans/vip/translate"
        var url = base+"?q="+str.urlEncoded()+"&appid="+appid+"&salt="+salt+"&sign="+sign+"&from="+from+"&to="+to;
        
        
        let srclang = determineLang(str: str)
        print(srclang,to)
        if (srclang == to && type=="copy") {
            return
        }
        else if (to == "auto" && srclang == "zh") {
            url = base+"?q="+str.urlEncoded()+"&appid="+appid+"&salt="+salt+"&sign="+sign+"&from=zh&to=en";
        }
        else if (to == "auto" && srclang == "en") {
            url = base+"?q="+str.urlEncoded()+"&appid="+appid+"&salt="+salt+"&sign="+sign+"&from=en&to=zh";
        }
        
        // 处理接口返回的JSON数据
        func getTranslationSuccess(data: Data?, response: URLResponse?, error: Error?) -> Void {
            DispatchQueue.main.async {
                do {
                    let decoder = JSONDecoder()
                    
                    struct Res: Codable {
                        var from: String
                        var to: String
                        var trans_result: [TransResult]
                        
                        struct TransResult: Codable {
                            let src: String
                            let dst: String
                        }
                    }
                    if (data != nil){
                        let r = try decoder.decode(Res.self, from: data!)
                        
                        tempTrans = r.trans_result[0].dst;
                        self.translatedText.stringValue = tempTrans;
//                        self.labelTouchBar(str: r.trans_result[0].dst)
                        
                        if (type == "copy" ) {
                            self.notify(title: r.trans_result[0].src,body: r.trans_result[0].dst)
                        }
                    }
                    
                } catch{
                    self.translatedText.stringValue = "Error";
                    if (type == "copy" ) {
                        self.notify(title: "Error",body: "Something just happened")
                    }
                    return
                }
            }
        }
        
        func sendGetRequest(url: String, completionHandler: @escaping ((Data?,URLResponse?,Error?)->Void)) {
            let session = URLSession(configuration: .default)
            let task = session.dataTask(with: URL(string: url)!, completionHandler: completionHandler)
            task.resume()
        }
        
        sendGetRequest(url: url, completionHandler: getTranslationSuccess(data:response:error:))
    }
    
    func md5Hash (str: String) -> String {
        if let strData = str.data(using: String.Encoding.utf8) {
            var digest = [UInt8](repeating: 0, count:Int(CC_MD5_DIGEST_LENGTH))
            strData.withUnsafeBytes {
                CC_MD5($0.baseAddress, UInt32(strData.count), &digest)
            }
            var md5String = ""
            for byte in digest {
                md5String += String(format:"%02x", UInt8(byte))
            }
            return md5String
        }
        return ""
    }
    
//    func labelTouchBar(str: String){
//        touchbarLabel.stringValue = str;
//        touchbarPopover.collapsedRepresentationLabel = str;
//    }
    
    func determineLang(str: String) -> String {
        for (_, value) in str.enumerated() {
            if ("\u{4E00}" <= value  && value <= "\u{9FA5}") {
                return "zh"
            }
        }
        return "en"
    }
    
    // 通知中心逻辑
    func notify(title: String, body: String){
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { success, error in
           if error == nil {
               if success == true {
                print("翻译成功")
                GoogleReporter.shared.event("首页", action: "复制翻译", label: title) //复制翻译的埋点事件
                
                let content = UNMutableNotificationContent()
                content.title = title;
                content.body = body;
                content.userInfo = ["method": "new"]

                content.categoryIdentifier = "TRANSLATION_RESULT"
                
                let acceptAction = UNNotificationAction(identifier: "SHOW_ACTION", title: "Copy", options: .init(rawValue: 0))
                let declineAction = UNNotificationAction(identifier: "CLOSE_ACTION", title: "Close", options: .init(rawValue: 0))
                let testCategory = UNNotificationCategory(identifier: "TRANSLATION_RESULT",
                                                          actions: [acceptAction,declineAction],
                                                          intentIdentifiers: [],
                                                          hiddenPreviewsBodyPlaceholder: "",
                                                          options: .customDismissAction)
                
                let request = UNNotificationRequest(identifier: "NOTIFICATION_REQUEST",
                                                    content: content,
                                                    trigger: nil)
                
                // Schedule the request with the system.
                let notificationCenter = UNUserNotificationCenter.current()
                notificationCenter.delegate = self
                notificationCenter.setNotificationCategories([testCategory])
                notificationCenter.add(request) { (error) in
                    if error != nil {
                        // Handle any errors.
                    }
                }
               }
               else {
                   print("接口拒绝")
               }
           }
           else {
               print("翻译出错")
           }
        }
    }
}

extension String {
     
    //将原始的url编码为合法的url
    func urlEncoded() -> String {
        let encodeUrlString = self.addingPercentEncoding(withAllowedCharacters:
            .urlQueryAllowed)
        return encodeUrlString ?? ""
    }
     
    //将编码后的url转换回原始的url
    func urlDecoded() -> String {
        return self.removingPercentEncoding ?? ""
    }
}

extension PopoverViewController: UNUserNotificationCenterDelegate {
    
    // 用户点击弹窗后的回调
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case "SHOW_ACTION":
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(tempTrans, forType: .string)
        case "CLOSE_ACTION":
            print("Nothing to do")
        default:
            break
        }
        completionHandler()
    }
    
    // 配置通知发起时的行为 alert -> 显示弹窗, sound -> 播放提示音
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}



class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    
    override func drawingRect(forBounds theRect: NSRect) -> NSRect {
        var newRect:NSRect = super.drawingRect(forBounds: theRect)
        let textSize:NSSize = self.cellSize(forBounds: theRect)
        let heightDelta:CGFloat = newRect.size.height - textSize.height
        if heightDelta > 0 {
            newRect.size.height = textSize.height
            newRect.origin.y += heightDelta / 2
        }
        return newRect
    }
}
