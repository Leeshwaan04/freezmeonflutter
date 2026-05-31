import 'package:flutter/material.dart';
import '../design_system.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton Loader Components
/// Premium loading states with shimmer effect

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: FreezmeDesignSystem.surface,
      highlightColor: FreezmeDesignSystem.background,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: FreezmeDesignSystem.surface,
          borderRadius: BorderRadius.circular(
            borderRadius ?? FreezmeDesignSystem.radiusSm,
          ),
        ),
      ),
    );
  }
}

/// Chat List Skeleton Loader
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: FreezmeDesignSystem.spaceMd),
      itemBuilder: (context, index) {
        return const ChatItemSkeleton();
      },
    );
  }
}

class ChatItemSkeleton extends StatelessWidget {
  const ChatItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
      decoration: FreezmeDesignSystem.cardDecoration,
      child: Row(
        children: [
          const SkeletonLoader(
            width: 56,
            height: 56,
            borderRadius: FreezmeDesignSystem.radiusFull,
          ),
          const SizedBox(width: FreezmeDesignSystem.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 120, height: 16),
                const SizedBox(height: FreezmeDesignSystem.spaceSm),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 14,
                ),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonLoader(width: 40, height: 12),
              SizedBox(height: FreezmeDesignSystem.spaceSm),
              SkeletonLoader(
                width: 24,
                height: 24,
                borderRadius: FreezmeDesignSystem.radiusFull,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Profile Card Skeleton
class ProfileCardSkeleton extends StatelessWidget {
  const ProfileCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceMd),
      decoration: FreezmeDesignSystem.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(
            width: double.infinity,
            height: 200,
            borderRadius: FreezmeDesignSystem.radiusLg,
          ),
          Padding(
            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 150, height: 20),
                const SizedBox(height: FreezmeDesignSystem.spaceSm),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 14,
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceSm),
                const SkeletonLoader(width: 100, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paths User Card Skeleton
class PathsUserSkeleton extends StatelessWidget {
  const PathsUserSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
      decoration: FreezmeDesignSystem.cardDecoration,
      child: const Row(
        children: [
          SkeletonLoader(
            width: 60,
            height: 60,
            borderRadius: FreezmeDesignSystem.radiusFull,
          ),
          SizedBox(width: FreezmeDesignSystem.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 100, height: 16),
                SizedBox(height: FreezmeDesignSystem.spaceSm),
                SkeletonLoader(width: 80, height: 14),
                SizedBox(height: FreezmeDesignSystem.spaceSm),
                Row(
                  children: [
                    SkeletonLoader(
                      width: 80,
                      height: 28,
                      borderRadius: FreezmeDesignSystem.radiusFull,
                    ),
                    SizedBox(width: FreezmeDesignSystem.spaceSm),
                    SkeletonLoader(
                      width: 80,
                      height: 28,
                      borderRadius: FreezmeDesignSystem.radiusFull,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live Card Skeleton (for Tonight page)
class LiveCardSkeleton extends StatelessWidget {
  const LiveCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: FreezmeDesignSystem.spaceMd),
      decoration: FreezmeDesignSystem.cardDecoration,
      padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonLoader(
            width: 48,
            height: 48,
            borderRadius: FreezmeDesignSystem.radiusFull,
          ),
          SizedBox(height: FreezmeDesignSystem.spaceSm),
          SkeletonLoader(width: 80, height: 12),
          SizedBox(height: FreezmeDesignSystem.spaceSm),
          SkeletonLoader(width: 60, height: 10),
        ],
      ),
    );
  }
}

/// Likes Grid Skeleton
class LikesGridSkeleton extends StatelessWidget {
  const LikesGridSkeleton({super.key, this.itemCount = 6});
  
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const SkeletonLoader(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        );
      },
    );
  }
}

