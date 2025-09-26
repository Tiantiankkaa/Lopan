//
//  PackagingTeamManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData

struct PackagingTeamManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var packagingTeams: [PackagingTeam]
    @Query private var products: [Product]
    
    @State private var showingAddTeam = false
    @State private var showingEditTeam: PackagingTeam?
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var teamsToDelete: IndexSet?
    
    private var filteredTeams: [PackagingTeam] {
        if searchText.isEmpty {
            return packagingTeams.sorted { $0.teamName < $1.teamName }
        } else {
            return packagingTeams.filter { team in
                team.teamName.localizedCaseInsensitiveContains(searchText) ||
                team.teamLeader.localizedCaseInsensitiveContains(searchText) ||
                team.members.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }.sorted { $0.teamName < $1.teamName }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar and add button
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索团队或成员", text: $searchText)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(LopanColors.backgroundTertiary)
                    .cornerRadius(10)
                    
                    Button(action: { showingAddTeam = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(LopanColors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(LopanColors.primary)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                // Teams list
                if filteredTeams.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 50))
                            .foregroundColor(LopanColors.secondary)
                        Text(searchText.isEmpty ? "暂无包装团队" : "未找到匹配的团队")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Text("点击右上角 + 按钮添加团队")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTeams, id: \.id) { team in
                            PackagingTeamRow(team: team, products: products) {
                                showingEditTeam = team
                            }
                        }
                        .onDelete(perform: confirmDelete)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("团队管理")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAddTeam) {
            AddPackagingTeamView()
        }
        .sheet(item: $showingEditTeam) { team in
            EditPackagingTeamView(team: team)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                teamsToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let offsets = teamsToDelete {
                    deleteTeams(offsets: offsets)
                }
                teamsToDelete = nil
            }
        } message: {
            Text("确定要删除选中的团队吗？此操作无法撤销。")
        }
    }
    
    private func confirmDelete(offsets: IndexSet) {
        teamsToDelete = offsets
        showingDeleteAlert = true
    }
    
    private func deleteTeams(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredTeams[index])
            }
        }
    }
}

struct PackagingTeamRow: View {
    let team: PackagingTeam
    let products: [Product]
    let onTap: () -> Void
    
    // Helper function to get product name from product ID
    private func productName(for productId: String) -> String {
        return products.first { $0.id == productId }?.name ?? "未知产品"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(team.teamName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Circle()
                        .fill(team.isActive ? LopanColors.success : LopanColors.secondary)
                        .frame(width: 8, height: 8)
                }
                
                HStack {
                    Label(team.teamLeader, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Label("\(team.members.count) 成员", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !team.specializedStyles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(team.specializedStyles.prefix(3), id: \.self) { productId in
                                Text(productName(for: productId))
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LopanColors.primary.opacity(0.1))
                                    .foregroundColor(LopanColors.info)
                                    .cornerRadius(4)
                            }
                            if team.specializedStyles.count > 3 {
                                Text("+\(team.specializedStyles.count - 3)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if !team.members.isEmpty {
                    Text("成员: \(team.members.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct AddPackagingTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var products: [Product]
    
    @State private var teamName = ""
    @State private var teamLeader = ""
    @State private var memberInput = ""
    @State private var members: [String] = []
    @State private var selectedStyles: Set<String> = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("团队信息")) {
                    TextField("团队名称", text: $teamName)
                    TextField("团队负责人", text: $teamLeader)
                }
                
                Section(header: Text("团队成员")) {
                    HStack {
                        TextField("添加成员", text: $memberInput)
                        Button("添加") {
                            addMember()
                        }
                        .disabled(memberInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    ForEach(members, id: \.self) { member in
                        HStack {
                            Text(member)
                            Spacer()
                            Button(action: {
                                removeMember(member)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(LopanColors.error)
                            }
                        }
                    }
                }
                
                Section(header: Text("专业款式 (可选)")) {
                    if products.isEmpty {
                        Text("暂无可选款式")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(products, id: \.id) { product in
                            HStack {
                                Button(action: {
                                    toggleStyleSelection(product.id)
                                }) {
                                    HStack {
                                        Image(systemName: selectedStyles.contains(product.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedStyles.contains(product.id) ? LopanColors.info : LopanColors.secondary)
                                        Text(product.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加团队")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTeam()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canSave: Bool {
        !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !teamLeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addMember() {
        let member = memberInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !member.isEmpty && !members.contains(member) {
            members.append(member)
            memberInput = ""
        }
    }
    
    private func removeMember(_ member: String) {
        members.removeAll { $0 == member }
    }
    
    private func toggleStyleSelection(_ styleCode: String) {
        if selectedStyles.contains(styleCode) {
            selectedStyles.remove(styleCode)
        } else {
            selectedStyles.insert(styleCode)
        }
    }
    
    private func saveTeam() {
        let team = PackagingTeam(
            teamName: teamName.trimmingCharacters(in: .whitespacesAndNewlines),
            teamLeader: teamLeader.trimmingCharacters(in: .whitespacesAndNewlines),
            members: members,
            specializedStyles: Array(selectedStyles)
        )
        
        modelContext.insert(team)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct EditPackagingTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var products: [Product]
    
    let team: PackagingTeam
    
    @State private var teamName: String
    @State private var teamLeader: String
    @State private var memberInput = ""
    @State private var members: [String]
    @State private var selectedStyles: Set<String>
    @State private var isActive: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(team: PackagingTeam) {
        self.team = team
        self._teamName = State(initialValue: team.teamName)
        self._teamLeader = State(initialValue: team.teamLeader)
        self._members = State(initialValue: team.members)
        self._selectedStyles = State(initialValue: Set(team.specializedStyles))
        self._isActive = State(initialValue: team.isActive)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("团队信息")) {
                    TextField("团队名称", text: $teamName)
                    TextField("团队负责人", text: $teamLeader)
                    Toggle("团队状态", isOn: $isActive)
                }
                
                Section(header: Text("团队成员")) {
                    HStack {
                        TextField("添加成员", text: $memberInput)
                        Button("添加") {
                            addMember()
                        }
                        .disabled(memberInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    ForEach(members, id: \.self) { member in
                        HStack {
                            Text(member)
                            Spacer()
                            Button(action: {
                                removeMember(member)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(LopanColors.error)
                            }
                        }
                    }
                }
                
                Section(header: Text("专业款式")) {
                    if products.isEmpty {
                        Text("暂无可选款式")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(products, id: \.id) { product in
                            HStack {
                                Button(action: {
                                    toggleStyleSelection(product.id)
                                }) {
                                    HStack {
                                        Image(systemName: selectedStyles.contains(product.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedStyles.contains(product.id) ? LopanColors.info : LopanColors.secondary)
                                        Text(product.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Section(header: Text("团队信息")) {
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(team.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("更新时间")
                        Spacer()
                        Text(team.updatedAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑团队")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canSave: Bool {
        !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !teamLeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addMember() {
        let member = memberInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !member.isEmpty && !members.contains(member) {
            members.append(member)
            memberInput = ""
        }
    }
    
    private func removeMember(_ member: String) {
        members.removeAll { $0 == member }
    }
    
    private func toggleStyleSelection(_ styleCode: String) {
        if selectedStyles.contains(styleCode) {
            selectedStyles.remove(styleCode)
        } else {
            selectedStyles.insert(styleCode)
        }
    }
    
    private func saveChanges() {
        team.teamName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        team.teamLeader = teamLeader.trimmingCharacters(in: .whitespacesAndNewlines)
        team.members = members
        team.specializedStyles = Array(selectedStyles)
        team.isActive = isActive
        team.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: PackagingTeam.self, ProductionStyle.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    PackagingTeamManagementView()
        .modelContainer(container)
}