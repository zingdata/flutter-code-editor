# Flutter Code Editor - Code Style & Conventions

## General Dart Principles

### Type Declarations
- Always declare types for variables and functions (parameters and return values)
- Avoid using `any` or dynamic types
- Create necessary custom types instead of using primitives

### Language
- Use English for all code and documentation

### Nomenclature
- **Classes**: PascalCase (e.g., `CodeController`, `CodeField`)
- **Variables/Functions/Methods**: camelCase (e.g., `foldAt`, `isLoading`)
- **Files/Directories**: underscores_case (e.g., `code_field.dart`, `line_numbers/`)
- **Constants**: UPPERCASE (e.g., `DEFAULT_TIMEOUT`)
- **Boolean Variables**: Start with verbs (e.g., `isLoading`, `hasError`, `canDelete`)
- **Functions**: Start with a verb (e.g., `executeValidation`, `saveState`, `isValid`)

### Well-known Abbreviations
- `i`, `j` for loops
- `err` for errors
- `ctx` for contexts
- `req`, `res`, `next` for middleware parameters

### File Organization
- One export per file
- No blank lines within a function
- Complete words instead of abbreviations (except standard ones like API, URL)

## Function Guidelines

### Function Size and Purpose
- Write short functions with a single purpose (< 20 instructions)
- Use meaningful names combining verb + noun
- For booleans: use `isX`, `hasX`, `canX`
- For actions: use `executeX`, `saveX`

### Function Structure
- Early checks and returns to avoid nesting
- Extract utility functions to reduce complexity
- Use higher-order functions (map, filter, reduce)
- Use arrow functions for simple operations (< 3 instructions)
- Use named functions for complex operations
- Use default parameter values instead of null checks
- Single level of abstraction per function

### Parameters
- Reduce function parameters using RO-RO pattern (Receive Object, Return Object)
- Use objects to pass multiple parameters
- Declare necessary types for input and output

## Data Guidelines

### Immutability
- Prefer immutability for data
- Use `readonly` for data that doesn't change
- Use `const` for literals that don't change
- Utilize `const` constructors to reduce rebuilds

### Data Validation
- Don't abuse primitive types
- Encapsulate data in composite types
- Avoid validation in functions; use classes with internal validation

## Class Guidelines

### SOLID Principles
- Follow SOLID design principles
- Prefer composition over inheritance
- Declare interfaces to define contracts

### Class Size
- Small classes with single purpose
- Less than 200 instructions
- Less than 10 public methods
- Less than 10 properties

## Flutter-Specific Guidelines

### Widget Structure
- Avoid deeply nesting widgets
- Break down large widgets into smaller, reusable components
- Keep widget tree flat for better performance and readability
- Deeply nested widgets impact build times and memory usage

### Architecture
- Use clean architecture principles
- Use repository pattern for data persistence
- Use pod pattern for business logic with Riverpod (Note: This package doesn't use Riverpod)
- Controllers take methods as input and update UI state

### State Management
- Manage state efficiently
- Avoid unnecessary rebuilds
- Use `const` constructors wherever possible

## Exception Handling

### When to Use Exceptions
- Handle errors you don't expect
- Catch exceptions only to:
  - Fix an expected problem
  - Add context
  - Otherwise use a global handler

## Linting Rules (from analysis_options.yaml)

### Enforced Rules
- `unawaited_futures`: error
- `unrelated_type_equality_checks`: error
- `avoid_relative_lib_imports`: error
- `always_use_package_imports`: warning
- `always_declare_return_types`: true
- `avoid_void_async`: true
- `avoid_redundant_argument_values`: true
- `avoid_unnecessary_containers`: true
- `sort_constructors_first`: true
- `prefer_const_constructors`: true
- `prefer_final_fields`: true

### Disabled Rules
- `depend_on_referenced_packages`: false
- `overridden_fields`: false
- `constant_identifier_names`: false
- `non_constant_identifier_names`: false
- `curly_braces_in_flow_control_structures`: false

### Ignored Warnings
- `invalid_annotation_target`: ignore
