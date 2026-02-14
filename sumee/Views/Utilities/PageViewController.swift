//
//  PageViewController.swift
//  sumee
//
//  Created for SUMEE to fix TabView animation issues.
//

import SwiftUI
import UIKit

struct PageViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]
    @Binding var currentPage: Int
    var orientation: UIPageViewController.NavigationOrientation = .horizontal

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: orientation
        )
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
  
        context.coordinator.updateControllers(with: pages)
     
        guard !pages.isEmpty else { return }
        
        let safeIndex = min(max(0, currentPage), pages.count - 1)
        
  
        let currentVC = pageViewController.viewControllers?.first as? UIHostingController<Page>
        
        
        let currentIndex = currentVC.flatMap { context.coordinator.controllers.firstIndex(of: $0) } ?? -1
        
        
        if currentIndex == safeIndex {
            return
        }

        let direction: UIPageViewController.NavigationDirection
        if currentIndex == -1 {
            direction = .forward
        } else {
            direction = safeIndex > currentIndex ? .forward : .reverse
        }
        
        guard safeIndex < context.coordinator.controllers.count else { return }
        let targetVC = context.coordinator.controllers[safeIndex]
        
    
        DispatchQueue.main.async {
            pageViewController.setViewControllers(
                [targetVC],
                direction: direction,
                animated: true,
                completion: nil
            )
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageViewController
        var controllers: [UIHostingController<Page>] = []

        init(_ parent: PageViewController) {
            self.parent = parent
       
             self.controllers = parent.pages.map { page in
                let vc = UIHostingController(rootView: page)
                vc.view.backgroundColor = .clear
                return vc
            }
        }
        
        func updateControllers(with newPages: [Page]) {
           
            if newPages.count > controllers.count {
       
                let deficit = newPages.count - controllers.count
                for _ in 0..<deficit {
                    let vc = UIHostingController(rootView: newPages[0])
                    vc.view.backgroundColor = .clear
                    controllers.append(vc)
                }
            } else if newPages.count < controllers.count {
             
                controllers = Array(controllers.prefix(newPages.count))
            }
            
    
            for (index, page) in newPages.enumerated() {
                controllers[index].rootView = page
            }
        }


        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let uiViewController = viewController as? UIHostingController<Page>,
                  let index = controllers.firstIndex(of: uiViewController) else {
                return nil
            }
            if index == 0 {
                return nil
            }
            return controllers[index - 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let uiViewController = viewController as? UIHostingController<Page>,
                  let index = controllers.firstIndex(of: uiViewController) else {
                return nil
            }
            if index + 1 == controllers.count {
                return nil
            }
            return controllers[index + 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            if completed,
               let visibleVC = pageViewController.viewControllers?.first as? UIHostingController<Page>,
               let index = controllers.firstIndex(of: visibleVC) {
        
                parent.currentPage = index
            }
        }
    }
}
