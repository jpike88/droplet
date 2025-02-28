//
//  DropletDropDelegate.swift
//  Droplet
//
//  Created by Josh McArthur on 9/11/21.
//

import SwiftUI
import SotoS3
import AVFoundation
import UserNotifications

struct DropletDropDelegate : DropDelegate {
    @AppStorage("awsAccessKeyId") var awsAccessKeyId = ""
    @AppStorage("awsSecretAccessKey") var awsSecretAccessKey = ""
    @AppStorage("awsRegion") var awsRegion = "";
    @AppStorage("awsBucketName") var awsBucketName = ""
    @AppStorage("customDomain") var customDomain = ""
    
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: ["public.file-url"])
    }
    
    
    func performDrop(info: DropInfo) -> Bool {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert]) { granted, error in }
        
        let awsClient = AWSClient(
            credentialProvider: .static(accessKeyId: awsAccessKeyId, secretAccessKey: awsSecretAccessKey),
            httpClientProvider: .createNew
        )
        let s3 = S3(client: awsClient, region: SotoS3.Region.init(rawValue: awsRegion));
        if let item = info.itemProviders(for: ["public.file-url"]).first {
            item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data {
                        self.active = true
                        self.fileUrl = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                        let key = NSUUID().uuidString + "." + self.fileUrl!.pathExtension;
                        let request = S3.CreateMultipartUploadRequest(bucket: awsBucketName,
                                                                      contentDisposition: "inline",
                                                                      contentType: self.fileUrl!.mimeType(),
                                                                      key: key)
                        let multipartUploadRequest = s3.multipartUpload(
                            request,
                            partSize: 5*1024*1024,
                            filename: self.fileUrl!.path,
                            abortOnFail: true,
                            on: nil,
                            threadPoolProvider: .createNew
                        ) { progress in
                            self.uploadProgress = progress
                        }
                        
                        multipartUploadRequest.whenFailure { error in
                            self.active = false;
                            print(error)
                            
                            DispatchQueue.main.async {
                                NSApplication.shared.presentError(error)
                            }
                            try! awsClient.syncShutdown()
                            
                        }
                        
                        multipartUploadRequest.whenSuccess { output in
                            DispatchQueue.main.async {
                                var location = output.location!
                                
                                if(self.customDomain.count > 0){
                                    location = "https://"+customDomain+"/"+key;
                                }
                                
                                self.generatedUrl = URL(string:location);
                                
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(location, forType: .string)
                                
                                notificationCenter.getNotificationSettings { settings in
                                    guard ((settings.authorizationStatus == .authorized) ||
                                           (settings.authorizationStatus == .provisional)) && settings.alertSetting == .enabled
                                    else { return }
                                    
                                    let content = UNMutableNotificationContent()
                                    content.title = "Upload finished"
                                    content.body = "URL has been copied to the clipboard"
                                    
                                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                                    let request = UNNotificationRequest(identifier: key, content: content, trigger: trigger)
                                    notificationCenter.add(request);
                                }
                                try! awsClient.syncShutdown()
                                self.active = false
                            }
                        }
                    }
                }
            }
            
            return true
            
        } else {
            return false
        }
        
    }
    
    @Binding var fileUrl: URL?
    @Binding var generatedUrl: URL?
    @Binding var active: Bool
    @Binding var uploadProgress: Double
}

