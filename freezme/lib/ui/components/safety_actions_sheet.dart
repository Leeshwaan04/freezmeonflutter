import 'package:flutter/material.dart';
import '../../controllers/flow_controller.dart';

/// Bottom sheet that lets the user Block or Report another user.
/// Apple App Review Guideline 1.2 requires both actions for any UGC app.
class SafetyActionsSheet {
  static Future<void> show(
    BuildContext context, {
    required String targetUid,
    required String targetName,
    String? context_,
    String? contextId,
    // Called after a successful block/report/unmatch so callers (e.g. the
    // Tonight pool / profile detail) can drop the resolved card.
    VoidCallback? onResolved,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.orange),
                title: const Text('Unmatch'),
                subtitle: const Text("Remove this match and chat history."),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _confirmAndUnmatch(context, targetUid, targetName, onResolved);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Color(0xFFEF4444)),
                title: const Text('Block user'),
                subtitle: Text("You won't see $targetName again."),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _confirmAndBlock(context, targetUid, targetName, onResolved);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: Color(0xFFEF4444)),
                title: const Text('Report user'),
                subtitle: const Text(
                    'Report inappropriate behavior. They will also be blocked.'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showReportSheet(
                    context,
                    targetUid: targetUid,
                    targetName: targetName,
                    context_: context_,
                    contextId: contextId,
                    onResolved: onResolved,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _confirmAndUnmatch(
      BuildContext context, String targetUid, String targetName, [VoidCallback? onResolved]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unmatch $targetName?'),
        content: const Text(
            "This will remove the match and delete your chat history. This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unmatch',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final flow = AppFlowScope.of(context);
    try {
      await flow.repository.unmatchUser(targetUid);
      onResolved?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unmatched with $targetName')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unmatch — please try again')),
        );
      }
    }
  }

  static Future<void> _confirmAndBlock(
      BuildContext context, String targetUid, String targetName, [VoidCallback? onResolved]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $targetName?'),
        content: const Text(
            "You won't be matched or see messages from this user. You can unblock them anytime from Settings."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final flow = AppFlowScope.of(context);
    try {
      await flow.repository.blockUser(targetUid);
      onResolved?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetName blocked')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to block — please try again')),
        );
      }
    }
  }

  static Future<void> _showReportSheet(
    BuildContext context, {
    required String targetUid,
    required String targetName,
    String? context_,
    String? contextId,
    VoidCallback? onResolved,
  }) async {
    const reasons = <Map<String, String>>[
      {'key': 'inappropriate', 'label': 'Inappropriate content'},
      {'key': 'harassment', 'label': 'Harassment or hate'},
      {'key': 'spam', 'label': 'Spam or scam'},
      {'key': 'fake', 'label': 'Fake profile'},
      {'key': 'underage', 'label': 'Underage user'},
      {'key': 'other', 'label': 'Other'},
    ];

    String? selectedReason;
    final detailsController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Report $targetName',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Reports are reviewed within 24 hours. This user will be blocked.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ...reasons.map((r) {
                        final selected = selectedReason == r['key'];
                        return InkWell(
                          onTap: () => setSheetState(
                              () => selectedReason = r['key']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFF3E8FF)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF9333EA)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected
                                      ? const Color(0xFF9333EA)
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(r['label']!,
                                    style: const TextStyle(fontSize: 15)),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailsController,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Add details (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: selectedReason == null
                              ? null
                              : () async {
                                  Navigator.pop(sheetCtx);
                                  await _submitReport(
                                    context,
                                    targetUid: targetUid,
                                    targetName: targetName,
                                    reason: selectedReason!,
                                    details: detailsController.text.trim(),
                                    context_: context_,
                                    contextId: contextId,
                                    onResolved: onResolved,
                                  );
                                },
                          child: const Text('Submit report'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    detailsController.dispose();
  }

  static Future<void> _submitReport(
    BuildContext context, {
    required String targetUid,
    required String targetName,
    required String reason,
    required String details,
    String? context_,
    String? contextId,
    VoidCallback? onResolved,
  }) async {
    final flow = AppFlowScope.of(context);
    try {
      await flow.repository.reportUser(
        targetUid,
        reason: reason,
        details: details.isEmpty ? null : details,
        context: context_,
        contextId: contextId,
      );
      onResolved?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Report submitted. $targetName has been blocked.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to submit report — please try again')),
        );
      }
    }
  }
}
