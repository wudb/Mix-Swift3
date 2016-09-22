//
//  ViewController.swift
//  Mix
//
//  Created by nc-wudb on 16/8/17.
//  Copyright (c) 2016 wudb. All rights reserved.
//


import UIKit


class ViewController: UITableViewController {

    let sectionTitles = ["WebKit", "TextKit", "CoreText"]
    let cellModels = ["WebKit": [("WebView", "MixWebViewController")],
                      "TextKit": [("Label", "MixLabelViewController"), ("TextView", "MixTextViewController"), ("TextView-Custom", "MixCustomTextViewController")],
                      "CoreText": [("CoreText-1", "CoreText1ViewController")]]


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.title = "图文混排"

    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: DataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.cellModels[self.sectionTitles[section]]?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MixCell")
        let sectionTexts = self.cellModels[self.sectionTitles[indexPath.section]]
        if let sections = sectionTexts {
            let record = sections[indexPath.row]
            cell?.textLabel?.text = record.0
        }
       
        return cell!
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }

    // MARK: Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionTexts = self.cellModels[self.sectionTitles[indexPath.section]]
        if let sections = sectionTexts {
            let record = sections[indexPath.row]
            let controllerClass = NSClassFromString("Mix_Swift3." + record.1) as? UIViewController.Type
            if let c = controllerClass {
                self.navigationController?.pushViewController(c.init(), animated: true)
            }
        }
    }

}
