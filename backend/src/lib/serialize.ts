import { prisma } from "./db";
import type { Channel, Poll, PollOption, Post, Comment } from "@prisma/client";

export type PostWithRelations = Post & {
  channel: Channel;
  poll: (Poll & { options: PollOption[] }) | null;
};

export type PostDto = {
  id: string;
  text: string;
  imageUrl: string | null;
  alias: string;
  emoji: string;
  authorName: string | null; // set when the author chose to post under their username
  channel: { slug: string; nameJa: string; emoji: string };
  score: number;
  myVote: number;
  commentCount: number;
  createdAt: string;
  isMine: boolean;
  poll: {
    id: string;
    totalVotes: number;
    myOptionId: string | null;
    options: { id: string; text: string; voteCount: number }[];
  } | null;
};

export type CommentDto = {
  id: string;
  parentId: string | null;
  alias: string;
  emoji: string;
  authorName: string | null;
  isOp: boolean;
  text: string;
  score: number;
  myVote: number;
  createdAt: string;
  isMine: boolean;
  isRemoved: boolean;
};

export async function toPostDtos(posts: PostWithRelations[], viewerId: string): Promise<PostDto[]> {
  const postIds = posts.map((p) => p.id);
  const pollIds = posts.filter((p) => p.poll).map((p) => p.poll!.id);

  const namedAuthorIds = [...new Set(posts.filter((p) => !p.isAnonymous).map((p) => p.authorId))];

  const [aliases, votes, pollVotes, namedAuthors] = await Promise.all([
    prisma.threadAlias.findMany({
      where: { OR: posts.map((p) => ({ postId: p.id, userId: p.authorId })) },
    }),
    prisma.vote.findMany({
      where: { userId: viewerId, targetType: "post", targetId: { in: postIds } },
    }),
    pollIds.length
      ? prisma.pollVote.findMany({ where: { userId: viewerId, pollId: { in: pollIds } } })
      : Promise.resolve([]),
    namedAuthorIds.length
      ? prisma.user.findMany({ where: { id: { in: namedAuthorIds } }, select: { id: true, username: true } })
      : Promise.resolve([]),
  ]);

  const usernameMap = new Map(namedAuthors.map((u) => [u.id, u.username]));
  const aliasMap = new Map(aliases.map((a) => [`${a.postId}:${a.userId}`, a]));
  const voteMap = new Map(votes.map((v) => [v.targetId, v.value]));
  const pollVoteMap = new Map(pollVotes.map((v) => [v.pollId, v.optionId]));

  return posts.map((p) => {
    const alias = aliasMap.get(`${p.id}:${p.authorId}`);
    return {
      id: p.id,
      text: p.text,
      imageUrl: p.imageUrl,
      alias: alias?.alias ?? "匿名",
      emoji: alias?.emoji ?? "👤",
      authorName: p.isAnonymous ? null : usernameMap.get(p.authorId) ?? null,
      channel: { slug: p.channel.slug, nameJa: p.channel.nameJa, emoji: p.channel.emoji },
      score: p.score,
      myVote: voteMap.get(p.id) ?? 0,
      commentCount: p.commentCount,
      createdAt: p.createdAt.toISOString(),
      isMine: p.authorId === viewerId,
      poll: p.poll
        ? {
            id: p.poll.id,
            totalVotes: p.poll.options.reduce((s, o) => s + o.voteCount, 0),
            myOptionId: pollVoteMap.get(p.poll.id) ?? null,
            options: p.poll.options
              .slice()
              .sort((a, b) => a.order - b.order)
              .map((o) => ({ id: o.id, text: o.text, voteCount: o.voteCount })),
          }
        : null,
    };
  });
}

export async function toCommentDtos(comments: Comment[], postId: string, viewerId: string): Promise<CommentDto[]> {
  const namedAuthorIds = [...new Set(comments.filter((c) => !c.isAnonymous).map((c) => c.authorId))];
  const [aliases, votes, namedAuthors] = await Promise.all([
    prisma.threadAlias.findMany({ where: { postId } }),
    prisma.vote.findMany({
      where: { userId: viewerId, targetType: "comment", targetId: { in: comments.map((c) => c.id) } },
    }),
    namedAuthorIds.length
      ? prisma.user.findMany({ where: { id: { in: namedAuthorIds } }, select: { id: true, username: true } })
      : Promise.resolve([]),
  ]);
  const aliasMap = new Map(aliases.map((a) => [a.userId, a]));
  const voteMap = new Map(votes.map((v) => [v.targetId, v.value]));
  const usernameMap = new Map(namedAuthors.map((u) => [u.id, u.username]));

  return comments.map((c) => {
    const alias = aliasMap.get(c.authorId);
    return {
      id: c.id,
      parentId: c.parentId,
      alias: alias?.alias ?? "匿名",
      emoji: alias?.emoji ?? "👤",
      authorName: c.isAnonymous ? null : usernameMap.get(c.authorId) ?? null,
      isOp: alias?.isOp ?? false,
      // Removed comments keep their place in the tree but hide content.
      text: c.isRemoved ? "（削除されました）" : c.text,
      score: c.score,
      myVote: voteMap.get(c.id) ?? 0,
      createdAt: c.createdAt.toISOString(),
      isMine: c.authorId === viewerId,
      isRemoved: c.isRemoved,
    };
  });
}
