//
//  ViewController.swift
//  ACBluetoothManager
//
//  Created by arges on 2019/11/12.
//  Copyright © 2019年 AlexCorleone. All rights reserved.
//

import UIKit
import CoreBluetooth

let kScreenWidth = UIScreen.main.bounds.size.width
let kScreenHeight = UIScreen.main.bounds.size.height
let kBlueToothCellIdentifier = "Alex.BlueToothCellIdentifier"
let serviceUUID = CBUUID.init(string: "Alex.ACBlueToothManagerServiceUUID")

let kConnectUUIDKey = "ACBlueToothUUIDKey"

/*  central(手机设备本身) 和 peripheral(外围设备)
     /*
     1、通过已知外围设备的服务UUID搜索（这个UUID是指被广播出来的服务UUID）；
     2、连接指定的外围设备；
     3、获取指定的服务，发现需要订阅的特征；
     4、接收外围设备发送的数据；
     5、向外围设备写数据；
     6、实现蓝牙服务的后台模式；
     7、实现蓝牙服务的状态保存与恢复（应用被系统杀死的时候，系统会自动保存 central manager 的状态）；
     */
 */


class ViewController: UIViewController {
    
    //MARK: - Var
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var central : CBCentral?
    private var peripherals: [CBPeripheral] = []//外围设备列表
    private var connectPeripheral: CBPeripheral?//当前连接的外围设备
    lazy var blueListTableView: UITableView = UITableView.init(frame: CGRect.init(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight),
                                                               style: .grouped)
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configSubviews()
        loadBlueToothData()
    }

    //MARK: - Private
    func configSubviews() {
        self.view.addSubview(blueListTableView)
        blueListTableView.delegate = self
        blueListTableView.dataSource = self;
        blueListTableView.register(UITableViewCell.self, forCellReuseIdentifier: kBlueToothCellIdentifier)
    }
    
    func loadBlueToothData() {
        //中心模式、 处理其他设备的广播
        let centralQueue = DispatchQueue.init(label: "Alex.CentralQueue")
        centralManager = CBCentralManager.init(delegate: self, queue: centralQueue)
        
        //外围模式、 广播给其他设备
        let peripheralQueue = DispatchQueue.init(label: "Alex.PeripheralQueue")
        peripheralManager = CBPeripheralManager.init(delegate: self, queue: peripheralQueue)
        //添加广播特征和服务
        let serviceUUID = CBUUID.init(string: "1800")

        let service = CBMutableService.init(type: serviceUUID, primary: true)
        let characteristicsUUIDRead = CBUUID.init(string: "0bd51666-e7cb-469b-8e4d-2742f1ba77cc")
        let readCharacteristics = CBMutableCharacteristic.init(type: characteristicsUUIDRead, properties: .read, value: nil, permissions: .readable)
        let value = "1111".data(using: .utf8)//!!!!! CBMutableCharacteristic value不为null时 只读
//        let uuidWrite = UUID.init(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5W")
//        let characteristicsUUIDWrite = CBUUID.init(nsuuid: uuidWrite!)
//        let writeCharacteristics = CBMutableCharacteristic.init(type: characteristicsUUIDWrite, properties: .write, value: value, permissions: .writeable)
        service.characteristics = [readCharacteristics]
        peripheralManager?.add(service)
        
        let advertising = [CBAdvertisementDataLocalNameKey : "virtual"]
        peripheralManager?.startAdvertising(advertising)
    }
}

extension ViewController: CBCentralManagerDelegate {
    
    //MARK: - CBCentralManagerDelegate
    //蓝牙状态变更会触发该方法调用
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("蓝牙未开启")
            bluetoothConfig.blueToothSettingPage()
        case .poweredOn:
            print("蓝牙已开启")
            central.scanForPeripherals(withServices: nil, options: nil)
        case .resetting:
            print("蓝牙重置中...")
        case .unauthorized:
            print("蓝牙未授权")
        case .unsupported:
            print("蓝牙不支持")
        case .unknown:
            print("蓝牙状态未知")
        default:
            print("----------")
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("锁屏 重连")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("发现新蓝牙设备")
        print("""
            蓝牙名字: \(peripheral.name)
            蓝牙状态: \(peripheral.state)
            蓝牙标识: \(peripheral.identifier)
            所有服务: \(peripheral.services)
            信号强弱: \(RSSI) \n
            """)
        if !self.peripherals.contains(peripheral) {
            self.peripherals.append(peripheral)
        }
        DispatchQueue.main.async {
            self.blueListTableView.reloadData()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("连接成功")
        connectPeripheral = peripheral
        _ = bluetoothConfig.saveNewBlueToothUUID(uuid: connectPeripheral?.identifier.uuidString)
        //指定连接设备代理
        connectPeripheral?.delegate = self
        //发现蓝牙服务
        connectPeripheral?.discoverServices([])
        //停止蓝牙设备搜索
        if let isScanning = centralManager?.isScanning {
            if isScanning {
                central.stopScan()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("断开连接")
    }
}

extension ViewController: CBPeripheralDelegate {
    
    //MARK: - CBPeripheralDelegate
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        print("连接设备的蓝牙名称发生改变  newName: \(String(describing: peripheral.name))")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("连接设备的蓝牙服务发生改变 newService: \(invalidatedServices)")
    }
    
    func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        print("连接设备的蓝牙RSSI已经更新 发起 read RSSI 请求")
        peripheral.readRSSI()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        print("读取到连接设备的蓝牙RSSI信息 new RSSI: \(RSSI) ERROR: \(String(describing: error))")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("发现连接设备蓝牙服务 error: \(String(describing: error))")
        guard let servicesList = connectPeripheral?.services else {
            print("连接设备未发现服务")
            return
        }
        if !servicesList.isEmpty {
//            for service in servicesList {
//                print("连接服务的UUID: \(service.uuid.uuidString)")
//                connectPeripheral?.discoverCharacteristics([], for:service)
//            }
            print("连接服务的UUID: \(servicesList.first?.uuid.uuidString)")
            connectPeripheral?.discoverCharacteristics([], for:servicesList.first!)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        print("通过调用 discoverIncludedServices 发现的service \(service)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("通过调用 discoverCharacteristics 发现的service \(service)")
        guard let serviceCharacters = service.characteristics else {
            return
        }
//        for character in serviceCharacters {
//            print("连接服务\(service.uuid.uuidString)特征的UUID: \(character.uuid.uuidString)")
//            connectPeripheral?.setNotifyValue(true, for: character)
//        }
        print("连接服务\(service.uuid.uuidString)特征的UUID: \(serviceCharacters.first?.uuid.uuidString)")
        connectPeripheral?.setNotifyValue(true, for: serviceCharacters.first!)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("""
            调用 readValue(for characteristic: 方法的回调
            UUID \(characteristic.uuid)
            data \(String(describing: String.init(data: characteristic.value ?? Data(), encoding: String.Encoding.utf8)))
            """)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("""
            调用 writeValue(_ data: 方法的回调
            UUID \(characteristic.uuid)
            data \(String(describing: String.init(data: characteristic.value ?? Data(), encoding: String.Encoding.utf8)))
            """)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("""
            调用 setNotifyValue(_ enabled: 方法的回调
            UUID \(characteristic.uuid)
            data \(String(describing: String.init(data: characteristic.value ?? Data(), encoding: String.Encoding.utf8)))
            """)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("""
            调用 readValue(for descriptor:  方法的回调
            UUID \(descriptor.uuid)
            data \(String(describing: String.init(data: descriptor.value! as! Data, encoding: String.Encoding.utf8)))
            """)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("""
            调用 writeValue(_ data: Data  方法的回调
            UUID \(descriptor.uuid)
            data \(String(describing: String.init(data: descriptor.value! as! Data, encoding: String.Encoding.utf8)))
            """)
    }
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        print("返回 openL2CAPChannel: 的调用结果")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        print("""
            调用 openL2CAPChannel:
            UUID \(String(describing: channel?.peer.identifier))
            PSM \(String(describing: channel?.psm))
            """)
    }
}

extension ViewController : CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("外设模式状态: \(peripheral.state)")
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    //MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let peripheral: CBPeripheral = self.peripherals[indexPath.row]
        centralManager?.connect(peripheral, options: [:])
    }
    
    //MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kBlueToothCellIdentifier)
        cell?.textLabel?.font = UIFont.systemFont(ofSize: 13)
        let peripheral: CBPeripheral = self.peripherals[indexPath.row]
        cell?.textLabel?.text = peripheral.name ?? peripheral.identifier.uuidString
        return cell!
    }
}

class bluetoothConfig {
    
    class func blueToothSettingPage() {
        DispatchQueue.main.async {
#if SO_DEBUG
            let url = URL.init(string: "App-Prefs:root=Bluetooth");
            if UIApplication.shared.canOpenURL(url!) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url!, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url!)
                }
            }
#else
            //将字符串转换为16进制
            let bytes: [UInt8] = [0x41, 0x70, 0x70, 0x2d, 0x50, 0x72, 0x65, 0x66, 0x73, 0x3a, 0x72, 0x6f, 0x6f, 0x74, 0x3d, 0x42, 0x6c, 0x75, 0x65, 0x74, 0x6f, 0x6f, 0x74, 0x68];
            let encryptString = Data.init(bytes: bytes, count: 24)
            let string = String.init(data: encryptString, encoding: String.Encoding.utf8)
            let url = URL.init(string: string!)
            if UIApplication.shared.canOpenURL(url!) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url!, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url!)
                }
            }
#endif
        }
    }
    
    class func saveNewBlueToothUUID(uuid: String?) -> Bool {
        guard let newvalue = uuid else {
            return false
        }
        UserDefaults.standard.set(newvalue, forKey: kConnectUUIDKey)
        return true
    }
}

