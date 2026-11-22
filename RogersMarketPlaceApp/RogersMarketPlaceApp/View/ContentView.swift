//
//  ContentView.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 19/11/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = MarketplaceVM.makeDefault()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                syncStatusBanner()
                listingsList()
            }
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $vm.searchText, prompt: "Search listings")
            .toolbar {
                addListingButton()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddListingScreen(vm: vm)
            }
        }
    }
}

private extension ContentView {
    @ViewBuilder
    func syncStatusBanner() -> some View {
        HStack(spacing: 8) {
            Text(vm.isOnline ? "Online • All Synced" : "Offline • Changes Queued")
                .font(.caption.bold())
                .frame(height: 20)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    func listingsList() -> some View {
        List(vm.filteredListings) { item in
            listingRow(for: item)
        }
        .animation(.snappy(duration: 0.25), value: vm.filteredListings.map(\.id))
        .refreshable {
            await vm.refreshProducts()
        }
    }

    @ViewBuilder
    func listingRow(for item: Listing) -> some View {
        HStack(spacing: 12) {
            listingThumbnail(for: item)

            Text(item.title)
                .font(.headline)

            Spacer()

            favoriteButton(for: item)
        }
    }

    @ViewBuilder
    func listingThumbnail(for item: Listing) -> some View {
        if let filename = item.imageFilename, let localImg = ImageStore.shared.loadImage(filename) {
            Image(uiImage: localImg)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let remoteURL = item.remoteImageURL {
            RemoteThumbnailView(
                urlString: remoteURL,
                cacheKey: "remote_\(item.id.uuidString).jpg"
            )
        } else {
            placeholderThumbnail()
        }
    }

    @ViewBuilder
    func placeholderThumbnail() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
            )
    }

    @ViewBuilder
    func favoriteButton(for item: Listing) -> some View {
        Button {
            vm.toggleFavorite(item)
        } label: {
            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(item.isFavorite ? .red : .gray)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func addListingButton() -> some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
}

private struct RemoteThumbnailView: View {
    let urlString: String
    let cacheKey: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: urlString) {
            image = await ImageStore.shared.loadRemoteThumbnail(urlString: urlString, cacheKey: cacheKey)
        }
    }
}

#Preview {
    ContentView()
}
