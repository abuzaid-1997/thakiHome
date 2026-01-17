//
//  SmartWebView.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 10/01/2026.
//

import SwiftUI
import WebKit

struct SmartWebView: UIViewRepresentable {
    let url: URL
    var onCompletion: (String) -> Void // لإرجاع الماك أدرس عند النجاح

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SmartWebView

        init(_ parent: SmartWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // نراقب الرابط إذا احتوى على نتيجة النجاح
            if let urlString = webView.url?.absoluteString {
                print("Current URL: \(urlString)")
                
                // إذا أرجعت البوردة صفحة النجاح (التي سنبرمجها لتعطي الماك)
                if urlString.contains("success") {
                    // هنا نفترض أننا سنمرر الماك أدرس في الرابط
                    // مثال: http://192.168.4.1/success?mac=600194108D1C
                    let components = URLComponents(string: urlString)
                    let mac = components?.queryItems?.first(where: { $0.name == "mac" })?.value ?? "unknown"
                    
                    parent.onCompletion(mac)
                }
            }
        }
    }
}
