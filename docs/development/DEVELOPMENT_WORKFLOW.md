# CloudToLocalLLM Development Workflow

This document describes the development workflow for the CloudToLocalLLM project. It is designed to ensure consistent code quality and streamline the development process.

## Collaborative Workflow with Gemini

This project follows a collaborative development workflow between the developer and the Gemini AI assistant.

**1. Plan the Work:**

* For each ticket, Gemini will analyze the requirements and propose a detailed implementation plan.
* The developer will review and approve the plan before any changes are made.

**2. Implement and Review:**

* Gemini will implement the changes as planned.
* After implementation, Gemini will present the changes to the developer for review.

**3. Commit and Push:**

* Once the developer approves the changes, Gemini will commit them to the `main` branch.
* The commit message will be descriptive and will include the ticket ID (e.g., `feat(cicd): CLO-32 Optimize GitHub Actions workflows`).

**4. Close the Ticket:**

* After the changes are committed and pushed, Gemini will close the corresponding ticket in Linear.

**5. Move to the Next Task:**

* With the previous ticket closed, we can then proceed to the next task in our plan.

## Coding Style

This project follows the standard Dart and Flutter coding styles. Please run `dart format .` to format your code before committing.

## Testing

All new features should be accompanied by tests. Please run `flutter test` to run the tests before committing.

## Code Reviews

All code changes should be reviewed by at least one other developer before being merged into the `main` branch.
