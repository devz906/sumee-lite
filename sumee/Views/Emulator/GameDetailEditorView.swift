import SwiftUI
import PhotosUI

struct GameDetailEditorView: View {
    let rom: ROMItem
    var onSave: (String, String?, UIImage?) -> Void // Updated signature to include URL
    var onCancel: () -> Void
    
    @State private var name: String
    @State private var launchURL: String // New state for URL Scheme
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoadingImage = false
    
    init(rom: ROMItem, onSave: @escaping (String, String?, UIImage?) -> Void, onCancel: @escaping () -> Void) {
        self.rom = rom
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: rom.displayName)
        _launchURL = State(initialValue: rom.externalLaunchURL ?? "") // Initialize with existing URL
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Game Info")) {
                    TextField("Name", text: $name)
                    
                    if rom.console == .ios {
                        VStack(alignment: .leading) {
                            TextField("URL Scheme (e.g. twitter://)", text: $launchURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Text("Enter the URL Scheme to launch this app (e.g., 'instagram://'). Bundle IDs are no longer supported.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Box Art")) {
                    VStack {
                        if let image = selectedImage ?? rom.getThumbnail() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .cornerRadius(12)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                        Text("No Image")
                                            .foregroundColor(.gray)
                                    }
                                )

                        }
                        
                        if isLoadingImage {
                            ProgressView("Processing...")
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.8)))
                        }
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Choose Image")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { onCancel() },
                trailing: Button("Save") {
                    onSave(name, launchURL.isEmpty ? nil : launchURL, selectedImage)
                }
            )
             .onChange(of: selectedItem) { newItem in
                 if let newItem = newItem {
                    isLoadingImage = true
                    Task {
                        // Compress/resize could be done here if needed
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                selectedImage = image
                                isLoadingImage = false
                            }
                        } else {
                            DispatchQueue.main.async {
                                isLoadingImage = false
                            }
                        }
                    }
                }
            }
        }
    }
}
