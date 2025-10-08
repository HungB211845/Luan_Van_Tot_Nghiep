# SPECS TEMPLATE: Module [Module Name]

> **Template Version**: 1.0  
> **Last Updated**: [Date]  
> **Implementation Status**: [Percentage]% Complete  
> **Multi-Tenant Ready**: ✅/🔶/❌  
> **Responsive Design**: ✅/🔶/❌

## 1. Tổng Quan

### a. Business Purpose
[Describe module's business purpose và key value propositions]

### b. Key Features
- **Feature 1**: [Description]
- **Feature 2**: [Description]
- **Integration**: [How this module integrates with others]

### c. Architecture Compliance
- **3-Layer Pattern**: UI → Provider → Service
- **Multi-Tenant**: Store isolation enforced
- **Responsive**: Universal design system applied

---

## 2. Cấu Trúc Dữ Liệu & Models

### a. Database Schema
```sql
-- Core tables với store isolation
CREATE TABLE [table_name] (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id),
  -- ... other fields
);
```

### b. Flutter Models
```dart
// lib/features/[module]/models/[model].dart
class [ModelName] {
  final String id;
  final String storeId; // Multi-tenant field
  // ... other properties
  
  // Required methods
  factory [ModelName].fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  [ModelName] copyWith({...});
}
```

### c. Relationships
- **1-to-Many**: [Description]
- **Many-to-Many**: [Description]
- **Cross-Module**: [References to other modules]

---

## 3. Luồng Kiến Trúc (3-Layer Implementation)

### a. Service Layer
**File**: `lib/features/[module]/services/[module]_service.dart`

```dart
class [ModuleName]Service extends BaseService {
  // CRUD operations với store isolation
  Future<List<[Model]>> get[Models]() async {
    return addStoreFilter(_supabase.from('[table]').select('*'))
      .order('[field]');
  }
  
  Future<[Model]> create[Model]([Model] model) async {
    final data = addStoreId(model.toJson());
    final response = await _supabase.from('[table]').insert(data).select().single();
    return [Model].fromJson(response);
  }
}
```

### b. Provider Layer  
**File**: `lib/features/[module]/providers/[module]_provider.dart`

```dart
enum [Module]Status { idle, loading, success, error }

class [Module]Provider extends ChangeNotifier {
  final [Module]Service _service = [Module]Service();
  
  // State management
  List<[Model]> _items = [];
  [Module]Status _status = [Module]Status.idle;
  String _errorMessage = '';
  
  // Safe loading pattern
  Future<void> load[Models]({bool forceReload = false}) async {
    if (_status == [Module]Status.loading && !forceReload) return;
    
    _status = [Module]Status.loading;
    _errorMessage = '';
    // DO NOT notifyListeners() here
    
    try {
      _items = await _service.get[Models]();
      _status = [Module]Status.success;
    } catch (e) {
      _status = [Module]Status.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners(); // Only notify once at end
    }
  }
}
```

### c. UI Layer
**File**: `lib/features/[module]/screens/[module]/[screen]_screen.dart`

```dart
class [Screen]Screen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold( // Standard responsive wrapper
      title: '[Screen Title]',
      body: Consumer<[Module]Provider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return LoadingWidget();
          if (provider.hasError) return ErrorWidget(provider.errorMessage);
          return _buildContent(provider.items);
        },
      ),
    );
  }
}
```

---

## 4. Responsive Design Implementation

### a. Screen Adaptation
```dart
return context.adaptiveWidget(
  mobile: _buildMobileLayout(),     // Single column
  tablet: _buildTabletLayout(),     // Two columns  
  desktop: _buildDesktopLayout(),   // Master-detail with top nav
);
```

### b. Platform-Aware Features
- **Mobile**: Touch optimizations, swipe gestures
- **Desktop**: Keyboard shortcuts, bulk operations, top navigation bar
- **Universal**: Auto-spacing với `context.sectionPadding`

---

## 5. Business Rules & Validation

### a. Core Business Rules
1. **Rule Name**: [Description và rationale]
2. **Validation**: [How it's enforced in code]
3. **Error Handling**: [User feedback mechanism]

### b. Multi-Tenant Rules
- **Store Isolation**: All operations scoped to user's store
- **Permission Checks**: Role-based access control
- **Data Validation**: Business constraints enforced

---

## 6. Integration Points

### a. Module Dependencies
- **[Module A]**: [How they interact]
- **[Module B]**: [Data flow description]

### b. Cross-Module Operations
```dart
// Example integration pattern
final result = await context.read<[Other]Provider>().method();
await context.read<[This]Provider>().processResult(result);
```

---

## 7. Performance Considerations

### a. Database Optimization
- **Indexes**: Optimized for common queries
- **RPC Functions**: Bulk operations where needed
- **Pagination**: Large datasets handled properly

### b. Memory Management
- **Provider Memory**: Efficient state management
- **Cache Strategy**: LRU cache where applicable
- **Resource Cleanup**: Proper disposal patterns

---

## 8. Implementation Status

### ✅ **COMPLETED**
- [List completed features]

### 🔶 **IN PROGRESS**  
- [List partially implemented features]

### ❌ **PLANNED**
- [List planned features]

---

## 9. Usage Examples

### a. Basic CRUD Operations
```dart
// Create
final newItem = await provider.create[Model](modelData);

// Read  
await provider.load[Models]();
final items = provider.items;

// Update
await provider.update[Model](updatedModel);

// Delete
await provider.delete[Model](itemId);
```

### b. Integration Examples
[Real code examples showing how this module works with others]

---

## 10. Testing & Quality Assurance

### a. Test Coverage
- **Unit Tests**: Service layer business logic
- **Widget Tests**: UI components và user interactions  
- **Integration Tests**: Cross-module workflows

### b. Quality Metrics
- **Performance**: Response time benchmarks
- **Memory**: Memory usage patterns
- **Security**: Store isolation verification

---

**Related Documentation**: 
- [Link to related module specs]
- [Link to architecture documentation]
- [Link to API documentation]

**Implementation Files**:
- Models: `lib/features/[module]/models/`
- Services: `lib/features/[module]/services/`  
- Providers: `lib/features/[module]/providers/`
- Screens: `lib/features/[module]/screens/`