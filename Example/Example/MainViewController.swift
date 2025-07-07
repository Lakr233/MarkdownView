//
//  MainViewController.swift
//  Example
//
//  Created by 秋星桥 on 7/8/25.
//

import UIKit

class MainViewController: UIViewController {
    let tableView = UITableView()
    let testCases = AllTestCases.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Markdown Test Cases"
        view.backgroundColor = .white
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.autoresizingMask = []
        view.addSubview(tableView)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }
}

extension MainViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        testCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let testCase = testCases[indexPath.row]
        cell.textLabel?.text = String(describing: testCase)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let testCase = testCases[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = MarkdownDocumentController(testCase: testCase)
        controller.title = String(describing: testCase)
        navigationController?.pushViewController(controller, animated: true)
    }
}
