import SwiftUI
import HealthKit

struct BodyFatLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var bodyFatText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var onSave: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Date")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)

                        Spacer()

                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    HStack {
                        Text("% Body Fat")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)

                        Spacer()

                        TextField("18.5", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .disabled(isSaving)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color("iosnp"))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.bottom, 20)
                }
            }
            .background(Color("iosbg").ignoresSafeArea())
            .navigationBarTitle("Body Fat", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Add") {
                    saveBodyFatLog()
                }
                .foregroundColor(.accentColor)
                .disabled(bodyFatText.isEmpty || isSaving)
            )
        }
    }

    private func saveBodyFatLog() {
        let sanitizedValue = bodyFatText.replacingOccurrences(of: "%", with: "")
        guard let value = Double(sanitizedValue), value > 0 else {
            errorMessage = "Enter a valid percentage"
            return
        }

        guard value >= 2 && value <= 75 else {
            errorMessage = "Enter a value between 2% and 75%"
            return
        }

        isSaving = true
        errorMessage = nil

        HealthKitManager.shared.checkAndRequestHealthPermissions { granted in
            DispatchQueue.main.async {
                guard granted else {
                    isSaving = false
                    errorMessage = "Enable Apple Health permissions to log body fat"
                    return
                }

                HealthKitManager.shared.saveBodyFatSample(percentage: value, date: selectedDate) { success, error in
                    isSaving = false
                    if success {
                        onSave?()
                        dismiss()
                    } else {
                        errorMessage = error?.localizedDescription ?? "Failed to save body fat entry"
                    }
                }
            }
        }
    }
}
