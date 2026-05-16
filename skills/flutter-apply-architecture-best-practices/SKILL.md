---
name: flutter-apply-architecture-best-practices
description: Architects a Flutter application using the recommended layered approach (UI, Logic, Data). Use when structuring a new project or refactoring for scalability.
---

# Architecting Flutter Applications

## Contents
- [Architectural Layers](#architectural-layers)
- [Project Structure](#project-structure)
- [Workflow: Implementing a New Feature](#workflow-implementing-a-new-feature)
- [Examples](#examples)
- [Usage](#usage)
- [Output](#output)
- [Present Results to User](#present-results-to-user)
- [Troubleshooting](#troubleshooting)

## Architectural Layers

Enforce strict Separation of Concerns by dividing the application into distinct layers. Never mix UI rendering with business logic or data fetching.

### UI Layer (Presentation)
Implement the MVVM (Model-View-ViewModel) pattern to manage UI state and logic.
*   **Views:** Write reusable, lean widgets. Restrict logic in Views to UI-specific operations (e.g., animations, layout constraints, simple routing). Pass all required data from the ViewModel.
*   **ViewModels:** Manage UI state and handle user interactions. Extend `ChangeNotifier` (or use `Listenable`) to expose state. Expose immutable state snapshots to the View. Inject Repositories into ViewModels via the constructor.

### Data Layer
Implement the Repository pattern to isolate data access logic and create a single source of truth.
*   **Services:** Create stateless classes to wrap external APIs (HTTP clients, local databases, platform plugins). Return raw API models or `Result` wrappers.
*   **Repositories:** Consume one or more Services. Transform raw API models into clean Domain Models. Handle caching, offline synchronization, and retry logic. Expose Domain Models to ViewModels.

### Logic Layer (Domain - Optional)
*   **Use Cases:** Implement this layer only if the application contains complex business logic that clutters the ViewModel, or if logic must be reused across multiple ViewModels. Extract this logic into dedicated Use Case (interactor) classes that sit between ViewModels and Repositories.

## Project Structure

Organize the codebase using a hybrid approach: group UI components by feature, and group Data/Domain components by type.

```text
lib/
├── data/
│   ├── models/         # API models
│   ├── repositories/   # Repository implementations
│   └── services/       # API clients, local storage wrappers
├── domain/
│   ├── models/         # Clean domain models
│   └── use_cases/      # Optional business logic classes
└── ui/
    ├── core/           # Shared widgets, themes, typography
    └── features/
        └── [feature_name]/
            ├── view_models/
            └── views/
```

## Workflow: Implementing a New Feature

Follow this sequential workflow when adding a new feature to the application. Copy the checklist to track progress.

### Task Progress
- [ ] **Step 1: Define Domain Models.** Create immutable data classes for the feature using `freezed`, `built_value`, or `@immutable` with `const` constructors.
- [ ] **Step 2: Implement Services.** Create or update Service classes to handle external API communication.
- [ ] **Step 3: Implement Repositories.** Create the Repository to consume Services and return Domain Models.
- [ ] **Step 4: Apply Conditional Logic (Domain Layer).**
  - *If the feature requires complex data transformation or cross-repository logic:* Create a Use Case class.
  - *If the feature is a simple CRUD operation:* Skip to Step 5.
- [ ] **Step 5: Implement the ViewModel.** Create the ViewModel extending `ChangeNotifier`. Inject required Repositories/Use Cases. Expose immutable state and command methods.
- [ ] **Step 6: Implement the View.** Create the UI widget. Use `ListenableBuilder` or `AnimatedBuilder` to listen to ViewModel changes.
- [ ] **Step 7: Inject Dependencies.** Register the new Service, Repository, and ViewModel in the dependency injection container (e.g., `provider` or `get_it`).
- [ ] **Step 8: Run Validator.** Execute unit tests for the ViewModel and Repository.
  - *Feedback Loop:* Run tests -> Review failures -> Fix logic -> Re-run until passing.

## Examples

### Data Layer: Service and Repository

```dart
// 1. Service (Raw API interaction)
class ApiClient {
  Future<UserApiModel> fetchUser(String id) async {
    // HTTP GET implementation...
  }
}

// 2. Repository (Single source of truth, returns Domain Model)
class UserRepository {
  UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final Map<String, User> _cache = {};

  Future<User> getUser(String id) async {
    if (_cache.containsKey(id)) return _cache[id]!;

    final apiModel = await _apiClient.fetchUser(id);
    final user = User(id: apiModel.id, name: apiModel.fullName); // Transform to Domain Model
    _cache[id] = user;
    return user;
  }
}
```

### UI Layer: ViewModel and View

```dart
// 3. ViewModel (State management and presentation logic)
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required UserRepository userRepository})
      : _userRepository = userRepository;

  final UserRepository _userRepository;

  User? _user;
  User? get user => _user;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadProfile(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _userRepository.getUser(id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// 4. View (Dumb UI component)
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = viewModel.error;
        if (error != null) {
          return Center(child: Text('Error: $error'));
        }

        final user = viewModel.user;
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        return Column(
          children: [
            Text(user.name),
            ElevatedButton(
              onPressed: () => viewModel.loadProfile(user.id),
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }
}
```

## Usage

This skill ships a validator script that scans a Flutter project for architectural violations and missing layer directories.

```bash
bash /mnt/skills/user/flutter-apply-architecture-best-practices/scripts/validate-structure.sh [project_directory]
```

**Arguments:**
- `project_directory` - Path to the Flutter project root (defaults to the current directory).

**Examples:**
```bash
# Validate the current directory
bash /mnt/skills/user/flutter-apply-architecture-best-practices/scripts/validate-structure.sh

# Validate a specific project
bash /mnt/skills/user/flutter-apply-architecture-best-practices/scripts/validate-structure.sh ./my_flutter_app
```

## Output

The script writes human-readable messages to **stderr** and a JSON summary to **stdout**.

Example JSON output:
```json
{
  "valid": true,
  "errors": 0,
  "layers": {
    "data": 12,
    "domain": 5,
    "ui": 28
  }
}
```

- `valid` - `true` if no warnings or errors were found.
- `errors` - Count of issues detected (missing directories or anti-patterns).
- `layers` - Number of `.dart` files found in each layer.

## Present Results to User

When reporting validator results, format them as follows:

1. **Status** - State whether validation passed or failed.
2. **Layer Breakdown** - Show the file count for Data, Domain, and UI layers.
3. **Issues** - List each warning or error with a concrete fix suggestion.
4. **Next Steps** - Recommend the highest-impact action (e.g., "Move HTTP calls from `lib/ui/` into a Service class").

Example:
> **Validation Failed** (3 issues)
>
> | Layer | Files |
> |-------|-------|
> | Data  | 12    |
> | Domain| 5     |
> | UI    | 28    |
>
> **Issues:**
> 1. Direct HTTP usage found in `lib/ui/features/login/views/login_view.dart`. Move API calls to a Service under `lib/data/services/`.
> 2. Missing `lib/domain` directory. Create it even if empty to preserve the intended structure.
>
> **Next Step:** Extract the HTTP client from the UI layer first.

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Missing Data layer directory" | `lib/data` does not exist. | Create `lib/data/models`, `lib/data/repositories`, and `lib/data/services`. |
| "Direct HTTP usage found in UI layer" | The validator detected `http`, `dio`, or `httpClient` in `lib/ui`. | Move the client call into a Service class. If the usage is inside a comment or a legitimate wrapper, move the wrapper to `lib/data/services`. |
| "State management found in Data layer" | `ChangeNotifier` or `ValueNotifier` was detected in `lib/data`. | Move the notifier into a ViewModel under `lib/ui/features/<feature>/view_models/`. |
| Validator reports 0 files in a layer | The directory exists but contains no `.dart` files yet. | This is expected for new projects. Populate the layer as you implement features. |
| `pubspec.yaml` not found | The script was run outside a Flutter project. | Pass the correct project directory as the first argument. |
