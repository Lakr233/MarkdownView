//
//  ContentController.swift
//  Example
//
//  Created by 秋星桥 on 1/20/25.
//

import MarkdownParser
import MarkdownView
import UIKit

final class ContentController: UIViewController {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [DocumentSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "MarkdownView"
        sections = DocumentMenu.sections

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)

        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 120))

        let playAllButton = UIButton(type: .system)
        playAllButton.setTitle("▶️ 测试所有文档流式渲染", for: .normal)
        playAllButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        playAllButton.addTarget(self, action: #selector(playAllDocuments), for: .touchUpInside)

        let infoLabel = UILabel()
        infoLabel.text = "点击任意文档查看详情\nPlay 按钮在详情页可用"
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center
        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabel

        footerView.addSubview(playAllButton)
        footerView.addSubview(infoLabel)

        playAllButton.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            playAllButton.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 20),
            playAllButton.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),

            infoLabel.topAnchor.constraint(equalTo: playAllButton.bottomAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
        ])

        tableView.tableFooterView = footerView
    }

    @objc func playAllDocuments() {
        let alert = UIAlertController(
            title: "测试流式渲染",
            message: "请选择一个文档进行测试，然后点击详情页右上角的 Play 按钮",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }
}

extension ContentController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].documents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let document = sections[indexPath.section].documents[indexPath.row]
        cell.textLabel?.text = document.title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].description
    }
}

extension ContentController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let document = sections[indexPath.section].documents[indexPath.row]
        let detailVC = DocumentDetailController(document: document.document, title: document.title)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
