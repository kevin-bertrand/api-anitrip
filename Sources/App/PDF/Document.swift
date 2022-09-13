//
//  Document.swift
//  
//
//  Created by Kevin Bertrand on 13/09/2022.
//

import Foundation
import NIO

public class Document {

    let zoom: String
    let topMargin: Int
    let rightMargin: Int
    let bottomMargin: Int
    let leftMargin: Int
    let launchPath: String

    let paperSize: String
    
    /// A list of extra arguments which will be send to wkhtmltopdf directly
    ///
    ///
    /// Examples: `["--disable-smart-shrinking", "--encoding", "<encoding>"]`
    let wkArgs: [String]

    public var pages: [Page] = []

    public init(size: String = "A4", zoom: String = "1.3", margins: Int = 20, path: String = "/usr/local/bin/wkhtmltopdf", wkArgs: [String] = []) {
        self.zoom = zoom
        self.paperSize = size
        self.topMargin = margins
        self.rightMargin = margins
        self.bottomMargin = margins
        self.leftMargin = margins
        self.launchPath = path
        self.wkArgs = wkArgs
    }

    public init(size: String = "A4", zoom: String = "1.3", top: Int = 20, right: Int = 20, bottom: Int = 20, left: Int = 20, path: String = "/usr/local/bin/wkhtmltopdf", wkArgs: [String] = []) {
        self.zoom = zoom
        self.paperSize = size
        self.topMargin = top
        self.rightMargin = right
        self.bottomMargin = bottom
        self.leftMargin = left
        self.launchPath = path
        self.wkArgs = wkArgs
    }
}

extension Document {
    public func generatePDF(on threadPool: NIOThreadPool, eventLoop: EventLoop, title: String) async throws -> Data {
        return try threadPool.runIfActive(eventLoop: eventLoop) {
            let fileManager = FileManager.default

            // Create the temp folder if it doesn't already exist
            let workDir = "/tmp/vapor-wkhtmltopdf"
            try fileManager.createDirectory(atPath: workDir, withIntermediateDirectories: true)

            // Save input pages to temp files, and build up args to wkhtmltopdf
            var wkArgs: [String] = [
                "--zoom", self.zoom,
                "--quiet",
                "--footer-center", "\(title) - Page [page]/[topage]",
                "--footer-font-size", "8",
                "--title", title,
                "-s", self.paperSize,
                "-T", "\(self.topMargin)mm",
                "-R", "\(self.rightMargin)mm",
                "-B", "\(self.bottomMargin)mm",
                "-L", "\(self.leftMargin)mm",
            ]
            
            wkArgs += self.wkArgs
            
            let pageFiles: [String] = try self.pages.map { page in
                let name = UUID().uuidString + ".html"
                let filename = "\(workDir)/\(name)"
                try page.content.write(to: URL(fileURLWithPath: filename))
                return filename
            }
            defer {
                try? pageFiles.forEach(fileManager.removeItem)
            }

            wkArgs += pageFiles
            
            // Call wkhtmltopdf and retrieve the result data
            let wk = Process()
            let stdout = Pipe()
            wk.launchPath = self.launchPath
            wk.arguments = wkArgs
            wk.arguments?.append("-") // output to stdout
            wk.standardOutput = stdout
            try wk.run()
            
            let pdf = stdout.fileHandleForReading.readDataToEndOfFile()
            return pdf
        }.wait()
    }
}

