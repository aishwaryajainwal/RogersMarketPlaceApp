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
                syncStatusBanner(isOnline: vm.isOnline)
                listingsList()
            }
            .navigationTitle("Marketplace")
            .toolbar {
                addListingButton()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddListingScreen(vm: vm)
            }
        }
    }
}

extension ContentView {
    @ViewBuilder
    func syncStatusBanner(isOnline: Bool) -> some View {
        HStack(spacing: 8) {
            Text(isOnline ? "Online • All Synced" : "Offline • Changes Queued")
                .font(.caption.bold())
            
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
        .searchable(text: $vm.searchText, prompt: "Search listings")
    }
    
    @ViewBuilder
    func listingRow(for item: Listing) -> some View {
        HStack(spacing: 12) {
            listingThumbnail(filename: item.imageFilename)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
            }
            Spacer()
            favoriteButton(for: item)
        }
    }
    
    @ViewBuilder
    func listingThumbnail(filename: String?) -> some View {
        if let img = ImageStore.shared.loadImage(filename) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                )
        }
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

#Preview {
    ContentView()
}
