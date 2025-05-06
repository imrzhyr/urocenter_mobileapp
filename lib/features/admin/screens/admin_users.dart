import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';

/// Admin users management screen
class AdminUsers extends ConsumerStatefulWidget {
  /// Constructor
  const AdminUsers({super.key});

  @override
  ConsumerState<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends ConsumerState<AdminUsers> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with search and filters
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                  onPressed: () {
                    // TODO: Implement filter functionality
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                  onPressed: () {
                    // TODO: Implement add user functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Users table
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 50, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 16),
                            Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Table content
                      Expanded(
                        child: ListView.builder(
                          itemCount: 10, // TODO: Replace with actual user data
                          itemBuilder: (context, index) {
                            // Mock user data
                            final user = {
                              'id': index + 1,
                              'name': 'User ${index + 1}',
                              'email': 'user${index + 1}@example.com',
                              'role': index % 3 == 0 ? 'Admin' : 'User',
                              'status': index % 4 == 0 ? 'Inactive' : 'Active',
                            };
                            
                            // Skip if it doesn't match the search query
                            if (!_filterUser(user)) {
                              return const SizedBox.shrink();
                            }
                            
                            final isActive = user['status'] == 'Active';
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 50, child: Text('#${user['id']}')),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: Text(user['name'] as String)),
                                  Expanded(flex: 2, child: Text(user['email'] as String)),
                                  Expanded(
                                    child: Chip(
                                      label: Text(user['role'] as String),
                                      backgroundColor: user['role'] == 'Admin' 
                                          ? AppColors.primary.withValues(alpha: 26.0)
                                          : AppColors.accent.withValues(alpha: 26.0),
                                      labelStyle: TextStyle(
                                        color: user['role'] == 'Admin' 
                                            ? AppColors.primary
                                            : AppColors.accent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Chip(
                                      label: Text(user['status'] as String),
                                      backgroundColor: isActive 
                                          ? AppColors.success.withValues(alpha: 26.0)
                                          : AppColors.error.withValues(alpha: 26.0),
                                      labelStyle: TextStyle(
                                        color: isActive ? AppColors.success : AppColors.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () {
                                            // TODO: Implement edit functionality
                                          },
                                          color: Colors.blue,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 20),
                                          onPressed: () {
                                            // TODO: Implement delete functionality
                                          },
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Previous'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('2'),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('3'),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter users based on search query
  bool _filterUser(Map<String, dynamic> user) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    final name = (user['name'] as String).toLowerCase();
    final email = (user['email'] as String).toLowerCase();
    
    return name.contains(query) || email.contains(query);
  }
} 