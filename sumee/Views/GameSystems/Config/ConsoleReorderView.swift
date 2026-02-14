import SwiftUI
import GameController

struct ConsoleReorderView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: GameSystemsViewModel
    @State private var consoles: [ROMItem.Console] = []
    
    // Controller State
    @State private var selectedIndex: Int = 0
    @State private var isGrabbing: Bool = false
    @State private var isControllerMode: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section(header: Text("Drag to Reorder")) {
                        ForEach(Array(consoles.enumerated()), id: \.element) { index, console in
                            HStack {
                                if isControllerMode {
                                    Image(systemName: "gamecontroller.fill")
                                        .foregroundColor(isGrabbing && index == selectedIndex ? .green : .gray)
                                }
                                
                                Text(console.systemName)
                                    .font(.headline)
                                    .foregroundColor((isControllerMode && index == selectedIndex) ? .blue : .primary)
                                
                                Spacer()
                                
                                if isControllerMode && index == selectedIndex {
                                    Image(systemName: isGrabbing ? "hand.draw.fill" : "arrow.left")
                                        .foregroundColor(isGrabbing ? .green : .blue)
                                }
                                // Standard List handles the drag icon in Edit Mode
                            }
                        }
                        .onMove(perform: move)
                    }
                }
                .environment(\.editMode, .constant(.active)) // Enable Touch dragging
                .onChange(of: selectedIndex) { _, newIndex in
                    if isControllerMode {
                        withAnimation {
                            if newIndex >= 0 && newIndex < consoles.count {
                                proxy.scrollTo(consoles[newIndex], anchor: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reorder Consoles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveOrder()
                        isPresented = false
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                self.consoles = viewModel.availableConsoles
                // Detect initial state
                self.isControllerMode = !GCController.controllers().isEmpty
            }
            // Controller Input Listener
            .onReceive(GameControllerManager.shared.inputPublisher) { event in
                if !isControllerMode { isControllerMode = true }
                handleInput(event)
            }
        }
    }
    
    func move(from source: IndexSet, to destination: Int) {
        consoles.move(fromOffsets: source, toOffset: destination)
    }
    
    func saveOrder() {
        viewModel.updateConsoleOrder(consoles)
    }
    
    //  Controller Logic
    
    func handleInput(_ event: GameControllerManager.GameInputEvent) {
        guard !consoles.isEmpty else { return }
        
        switch event {
        case .up(let repeated):
            if selectedIndex > 0 {
                AudioManager.shared.playSelectSound()
                if isGrabbing {
                     // Move Item Up
                     let source = IndexSet(integer: selectedIndex)
                     let destination = selectedIndex - 1
                     withAnimation {
                         consoles.move(fromOffsets: source, toOffset: destination)
                         selectedIndex -= 1
                     }
                } else {
                     withAnimation { selectedIndex -= 1 }
                }
            }
            
        case .down(let repeated):
            if selectedIndex < consoles.count - 1 {
                AudioManager.shared.playSelectSound()
                if isGrabbing {
                    // Move Item Down
                    let source = IndexSet(integer: selectedIndex)
                    let destination = selectedIndex + 2 
                    withAnimation {
                        consoles.move(fromOffsets: source, toOffset: destination)
                        selectedIndex += 1
                    }
                } else {
                    withAnimation { selectedIndex += 1 }
                }
            }
            
        case .a:
            AudioManager.shared.playSelectSound()
            withAnimation { isGrabbing.toggle() }
            
        case .b:
            AudioManager.shared.playSelectSound()
            if isGrabbing {
                withAnimation { isGrabbing = false } // Cancel Grab
            } else {
                isPresented = false // Exit (Simulate Cancel)
            }
            
        case .start:
             // Save and Exit
             AudioManager.shared.playSelectSound()
             saveOrder()
             isPresented = false
             
        default: break
        }
    }
}
