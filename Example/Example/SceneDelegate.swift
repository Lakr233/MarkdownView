//
//  SceneDelegate.swift
//  Example
//
//  Created by 秋星桥 on 7/8/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        guard let windowScene = (scene as? UIWindowScene) else { return }
        #if targetEnvironment(macCatalyst)
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
        #endif
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 650, height: 650)
        let window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController(rootViewController: MainViewController())
        nav.navigationBar.prefersLargeTitles = false
        nav.view.backgroundColor = .systemBackground
        nav.navigationBar.backgroundColor = .systemBackground
        let bg = UIView()
        bg.backgroundColor = .systemBackground
        nav.navigationBar.addSubview(bg)
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.autoresizingMask = []
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: nav.navigationBar.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: nav.navigationBar.trailingAnchor),
            bg.topAnchor.constraint(equalTo: nav.navigationBar.topAnchor, constant: -100),
            bg.bottomAnchor.constraint(equalTo: nav.navigationBar.bottomAnchor),
        ])
        bg.layer.zPosition = -1
        bg.isUserInteractionEnabled = false
        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
