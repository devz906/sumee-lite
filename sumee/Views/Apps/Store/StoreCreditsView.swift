import SwiftUI

struct StoreCreditsView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var storeViewModel: StoreViewModel
    
    // Grid columns based on layout (responsive)
    let columns = [
        GridItem(.adaptive(minimum: 300), spacing: 16)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Disclaimer
                    VStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                        Text("Disclaimer")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("SUMEE! does not own any rights to the intellectual property of the applications listed below. All credits belong to their respective creators.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    
                    // Credits List
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<storeViewModel.credits.count, id: \.self) { index in
                            let item = storeViewModel.credits[index]
                            let isSelected = storeViewModel.selectedCreditIndex == index
                            
                            CreditCard(item: item, isSelected: isSelected)
                                .id(index) // Important for ScrollViewReader
                                .onTapGesture {
                                    storeViewModel.selectedCreditIndex = index
                                    storeViewModel.handleSelect()
                                }
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 80)
            }
            .onChange(of: storeViewModel.selectedCreditIndex) { newIndex in
                 withAnimation {
                     proxy.scrollTo(newIndex, anchor: .center)
                 }
            }
        }
    }
}

struct CreditCard: View {
    let item: CreditItem
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Group {
                if let app = item.systemApp {
                    Image(app.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(item.role)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let link = item.discordLink, !link.isEmpty {
                // Use requested asset icon "icon_discord"
                Image("icon_discord")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24) // Adjusted size for custom icon
                    .padding(8)
                    .background(Color(red: 88/255, green: 101/255, blue: 242/255).opacity(0.1)) // Blurple tint
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .background(
             RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .cornerRadius(16)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
