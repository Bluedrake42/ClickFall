import SwiftUI

// Simple data structure for list items
struct ListItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let systemImageName: String
}

// Sample data
let sampleListData = [
    ListItem(name: "Item 1", description: "Details about item 1", systemImageName: "star.fill"),
    ListItem(name: "Item 2", description: "Details about item 2", systemImageName: "heart.fill"),
    ListItem(name: "Item 3", description: "Details about item 3", systemImageName: "bookmark.fill"),
    ListItem(name: "Item 4", description: "Details about item 4", systemImageName: "flag.fill"),
    ListItem(name: "Item 5", description: "Details about item 5", systemImageName: "bell.fill"),
]

struct ListView: View {
    // State to hold the list data
    @State private var items = sampleListData

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    NavigationLink(destination: DetailView(item: item)) {
                        HStack(spacing: 15) {
                            Image(systemName: item.systemImageName)
                                .foregroundColor(.blue)
                                .frame(width: 30) // Align icons
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 5) // Add vertical padding for better spacing
                    }
                }
                // Add swipe-to-delete functionality
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Items List")
            // Add an EditButton to allow rearranging/deleting
            .toolbar {
                EditButton()
            }
        }
    }

    // Function to delete items from the list
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

// Detail view to show when a list item is tapped
struct DetailView: View {
    let item: ListItem

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: item.systemImageName)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(.blue)
                .padding(.top, 30)

            Text(item.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(item.description)
                .font(.title2)
                .padding()

            Spacer()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ListView()
} 