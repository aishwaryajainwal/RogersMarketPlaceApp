//
//  AddListingScreen.swift
//  RogersMarketPlaceApp
//
//  Created by TINA JAINWAL on 20/11/26.
//

import PhotosUI
import SwiftUI


struct AddListingScreen: View {
    @ObservedObject var vm: MarketplaceVM
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false

    @State private var title = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    private var isValid: Bool {
        title.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item Title", text: $title)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(selectedImage == nil ? "Attach Photo" : "Change Photo", systemImage: "photo")
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImage = UIImage(data: data)
                        }
                    }
                }
                
                Button {
                    showingCamera = true
                } label: {
                    Label("Open Camera", systemImage: "camera")
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                }
            }
            .navigationTitle("New Listing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.addListing(title: title, image: selectedImage)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) { CameraPicker(selectedImage: $selectedImage)
            }
        }
    }
}

#Preview {
    AddListingScreen(vm: MarketplaceVM.makeDefault())
}
