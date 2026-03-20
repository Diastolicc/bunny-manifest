# Contributing to Club Reservation App

Thank you for your interest in contributing to the Club Reservation App! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue template** provided
3. **Provide detailed information** including:
   - Flutter/Dart version
   - Platform (iOS/Android/Web)
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots/videos if applicable

### Suggesting Enhancements

We welcome feature requests! Please:

1. **Check existing feature requests** first
2. **Use the feature request template**
3. **Provide clear use cases** and benefits
4. **Consider implementation complexity**

### Code Contributions

#### Getting Started

1. **Fork the repository**
2. **Clone your fork**:
   ```bash
   git clone https://github.com/yourusername/club_reservation.git
   cd club_reservation
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Set up the development environment**:
   ```bash
   flutter pub get
   flutter pub run build_runner build
   ```

#### Development Guidelines

##### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Run `dart format .` to format your code
- Follow the existing code patterns in the project

##### Architecture

- **State Management**: Use Provider pattern
- **Routing**: Use GoRouter for navigation
- **Models**: Use Freezed for immutable data classes
- **Services**: Keep business logic in service classes
- **Widgets**: Create reusable widgets in the `widgets/` directory

##### File Organization

```
lib/
├── models/          # Data models with Freezed
├── providers/       # State management
├── services/        # Business logic
├── screens/         # UI screens
├── widgets/         # Reusable components
├── router/          # Navigation configuration
├── theme/           # App theming
└── utils/           # Utility functions
```

##### Naming Conventions

- **Files**: Use snake_case (e.g., `user_profile_screen.dart`)
- **Classes**: Use PascalCase (e.g., `UserProfileScreen`)
- **Variables/Functions**: Use camelCase (e.g., `userName`, `getUserData()`)
- **Constants**: Use SCREAMING_SNAKE_CASE (e.g., `API_BASE_URL`)

#### Testing

- Write unit tests for business logic
- Write widget tests for UI components
- Ensure all tests pass before submitting PR
- Aim for meaningful test coverage

```bash
# Run tests
flutter test

# Run tests with coverage
flutter test --coverage
```

#### Commit Guidelines

Use conventional commits format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(auth): add social login support
fix(reservation): resolve booking time conflict
docs(readme): update installation instructions
```

#### Pull Request Process

1. **Ensure your branch is up to date**:
   ```bash
   git checkout main
   git pull origin main
   git checkout your-feature-branch
   git rebase main
   ```

2. **Run all checks**:
   ```bash
   flutter analyze
   flutter test
   flutter pub run build_runner build
   ```

3. **Create a Pull Request**:
   - Use a clear, descriptive title
   - Fill out the PR template
   - Link related issues
   - Add screenshots for UI changes
   - Request review from maintainers

4. **Respond to feedback**:
   - Address review comments promptly
   - Make requested changes
   - Keep discussions constructive

## 🏗️ Development Setup

### Prerequisites

- Flutter SDK 3.5.0+
- Dart SDK 3.5.0+
- Android Studio / VS Code
- Firebase CLI
- Git

### Environment Setup

1. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

2. **Generate code**:
   ```bash
   flutter pub run build_runner build
   ```

3. **Set up Firebase** (for testing):
   - Create a test Firebase project
   - Add configuration files
   - Update `firebase_options.dart`

4. **Run the app**:
   ```bash
   flutter run
   ```

### Code Generation

The project uses code generation for models and serialization:

```bash
# Watch for changes and regenerate
flutter pub run build_runner watch

# One-time generation
flutter pub run build_runner build

# Clean and regenerate
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🐛 Debugging

### Common Issues

1. **Build failures**: Run `flutter clean && flutter pub get`
2. **Code generation issues**: Run `flutter pub run build_runner build --delete-conflicting-outputs`
3. **Firebase issues**: Check configuration files and rules

### Debug Tools

- Use `flutter logs` for runtime debugging
- Use `flutter inspector` for widget debugging
- Use Firebase Console for backend debugging

## 📋 Review Process

### What We Look For

- **Code Quality**: Clean, readable, well-documented code
- **Architecture**: Follows project patterns and best practices
- **Testing**: Adequate test coverage
- **Performance**: No obvious performance issues
- **Security**: No security vulnerabilities
- **Documentation**: Updated documentation for new features

### Review Timeline

- Initial review: Within 2-3 business days
- Follow-up reviews: Within 1-2 business days
- Final approval: Depends on complexity and feedback

## 🎯 Areas for Contribution

### High Priority

- Bug fixes and stability improvements
- Performance optimizations
- Security enhancements
- Documentation improvements

### Medium Priority

- New features (with prior discussion)
- UI/UX improvements
- Test coverage improvements
- Code refactoring

### Low Priority

- Minor UI tweaks
- Additional platforms support
- Advanced features

## 📞 Getting Help

- **GitHub Discussions**: For questions and general discussion
- **Issues**: For bug reports and feature requests
- **Discord/Slack**: [Add your community link]
- **Email**: [Add maintainer contact]

## 📜 Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Expected Behavior

- Be respectful and inclusive
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment, trolling, or discrimination
- Personal attacks or political discussions
- Spam or off-topic discussions
- Any other unprofessional conduct

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

## 🙏 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing to the Club Reservation App! 🚀

