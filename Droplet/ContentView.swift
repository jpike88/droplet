//
//  ContentView.swift
//  Droplet
//
//  Created by Josh McArthur on 9/11/21.
//

import SwiftUI

struct DroppableArea: View {
    @State private var fileUrl: URL?
    @State private var generatedUrl: URL?
    @State private var active = false
    @State private var uploadProgress = 0.0;
    
    

    var body: some View {
        
        let dropDelegate = DropletDropDelegate(fileUrl: $fileUrl, generatedUrl: $generatedUrl, active: $active, uploadProgress: $uploadProgress)
        
        VStack {
            Image("HeroImage")
            if self.active {
                ProgressView(value: uploadProgress, total: 1.0).padding()
            } else if (self.generatedUrl != nil) {
                Link("Open link in browser", destination: self.generatedUrl!).padding()
                Spacer()
                Button("Reset", action: { self.generatedUrl = nil }).buttonStyle(.borderless)
            } else {
                Text("Drop file here to upload").padding()
                Spacer()
                Button("Settings", action: {
                    NSApp.sendAction(#selector(DropletAppDelegate.showSettings), to: nil, from:nil)

                })
                Button("Quit", action: { exit(0) }).buttonStyle(.borderless)
                Text("jpike88/droplet").opacity(0.4)
            }
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding().fixedSize()
    .onDrop(of: ["public.file-url"], delegate: dropDelegate)
    }
}

struct ContentView: View {
    var body = DroppableArea()

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
