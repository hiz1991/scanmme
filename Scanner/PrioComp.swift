

import SwiftUI

struct iPhonePortrait: View {
    @State private var isSectionTitleOn = true
    @State private var isImportanceOn = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Document Title
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "app")
                        .foregroundColor(Color.blue)
                        .padding(.leading, 5)
                    Text("Document Title")
                        .foregroundColor(Color.white)
                    Spacer()
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.27))
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                ForEach(0..<5) { _ in
                    HStack {
                        Text("Item")
                            .foregroundColor(Color.white)
                            .padding(.leading, 20)
                        Spacer()
                        Image(systemName: "app.dashed")
                            .foregroundColor(Color.white)
                            .padding(.trailing, 20)
                    }
                    .frame(height: 40)
                    .background(Color.black.opacity(0.27))
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 24)
            .background(Color.clear)
            .cornerRadius(15)
            
            // Section Title
            VStack {
                HStack {
                    Image(systemName: "doc.plaintext")
                        .foregroundColor(Color.white)
                        .padding(5)
                    Text("Section title")
                        .foregroundColor(Color.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.blue)
                        .padding(5)
                }
                .padding(.vertical, 10)
                .background(Color.clear)
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white, lineWidth: 1)
                )
                
                HStack {
                    Text("Recognized text. A lot of it. A lot")
                        .font(.system(size: 8))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(5)
                }
                .background(Color.gray.opacity(0.27))
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.gray, lineWidth: 1)
                )
                
                Toggle(isOn: $isSectionTitleOn) {
                    Text("")
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.green))
            }
            .padding(.horizontal, 24)
            .background(Color.clear)
            
            // Importance Section
            VStack {
                HStack {
                    Image(systemName: "doc.plaintext")
                        .foregroundColor(Color.white)
                        .padding(5)
                    Text("Importance")
                        .foregroundColor(Color.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.blue)
                        .padding(5)
                }
                .padding(.vertical, 10)
                .background(Color.clear)
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.red, lineWidth: 1)
                )
                
                HStack {
                    Text("High")
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(5)
                }
                .frame(width: 166, height: 39)
                .background(Color.red.opacity(0.21))
                .cornerRadius(10)
                
                Toggle(isOn: $isImportanceOn) {
                    Text("")
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.green))
            }
            .padding(.horizontal, 24)
            .background(Color.clear)
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}

struct iPhonePortrait_Previews: PreviewProvider {
    static var previews: some View {
        iPhonePortrait()
    }
}
