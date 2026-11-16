namespace HuskeMester.Game;

/// <summary>One card on the board. Two cards share each picture.</summary>
public sealed class Card(int index, string emoji)
{
    /// <summary>The card's place among the cards (the free star is not counted).</summary>
    public int Index { get; } = index;
    public string Emoji { get; } = emoji;
    public bool IsUp { get; internal set; }
    public bool IsMatched { get; internal set; }
}

public enum FlipResult
{
    /// <summary>The card can't be turned: it is already up, or two cards are waiting to be turned back.</summary>
    Ignored,
    /// <summary>The first card of a move.</summary>
    First,
    /// <summary>The second card has the same picture as the first.</summary>
    Match,
    /// <summary>The second card has a different picture; both go back with <see cref="MemoryGame.HideMiss"/>.</summary>
    Miss,
}

/// <summary>
/// The memory game: an N×N board of face-down cards, with every picture twice. Turn two at a time;
/// a pair stays up, two different pictures are turned back. On an odd board the middle cell is a free star.
/// </summary>
public sealed class MemoryGame
{
    public static readonly int[] Sizes = [2, 3, 4, 5, 6, 7, 8];

    /// <summary>Child-friendly emoji, one code point each. 8×8 needs 32 different ones.</summary>
    public static readonly IReadOnlyList<string> Pool =
    [
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
        "🐧", "🐤", "🦆", "🦉", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐢", "🦖", "🐙", "🦀", "🐠",
        "🐬", "🐳", "🦈", "🐊", "🦒", "🐘", "🦔",
        "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍒", "🍑", "🍍", "🥝", "🥕", "🌽", "🍄", "🍕",
        "🍔", "🍟", "🍩", "🍪", "🎂", "🍦", "🍭",
        "⚽", "🏀", "🎈", "🎁", "🚗", "🚌", "🚒", "🚑", "🚜", "🚲", "🚀", "🚁", "⛵", "🌈", "🌙", "🌻",
        "🌷", "🌵", "🌲", "🎸", "🥁", "🎺", "🧸", "🎨", "🔔",
    ];

    private readonly Random _random;
    private readonly List<Card?> _cells = [];
    private readonly List<string> _pictures = [];
    private Card? _first;
    private (Card A, Card B)? _miss;

    public MemoryGame(Random? random = null) => _random = random ?? Random.Shared;

    public int Size { get; private set; }

    /// <summary>The board row by row; null is the free star in the middle of an odd board.</summary>
    public IReadOnlyList<Card?> Cells => _cells;

    /// <summary>The pictures in this game, one of each.</summary>
    public IReadOnlyList<string> Pictures => _pictures;

    public int CardCount => _cells.Count(c => c is not null);
    public int TotalPairs => _pictures.Count;
    public int Pairs { get; private set; }
    public int Moves { get; private set; }
    public bool IsWon => TotalPairs > 0 && Pairs == TotalPairs;

    /// <summary>Two different cards are up and must be turned back before the next move.</summary>
    public bool IsWaiting => _miss is not null;

    public void NewGame(int size)
    {
        if (!Sizes.Contains(size)) throw new ArgumentOutOfRangeException(nameof(size));

        Size = size;
        Pairs = 0;
        Moves = 0;
        _first = null;
        _miss = null;

        _pictures.Clear();
        _pictures.AddRange(Pool.OrderBy(_ => _random.Next()).Take(size * size / 2));

        var deck = _pictures.Concat(_pictures).ToArray();
        _random.Shuffle(deck);

        _cells.Clear();
        var index = 0;
        foreach (var emoji in deck)
        {
            if (size % 2 == 1 && _cells.Count == size * size / 2) _cells.Add(null);
            _cells.Add(new Card(index++, emoji));
        }
    }

    public FlipResult Flip(Card card)
    {
        if (card.IsUp || card.IsMatched || _miss is not null || IsWon) return FlipResult.Ignored;

        card.IsUp = true;
        if (_first is null)
        {
            _first = card;
            return FlipResult.First;
        }

        var first = _first;
        _first = null;
        Moves++;

        if (first.Emoji == card.Emoji)
        {
            first.IsMatched = card.IsMatched = true;
            Pairs++;
            return FlipResult.Match;
        }

        _miss = (first, card);
        return FlipResult.Miss;
    }

    /// <summary>Turns the two different cards from the last move face down again.</summary>
    public void HideMiss()
    {
        if (_miss is not { } miss) return;
        miss.A.IsUp = miss.B.IsUp = false;
        _miss = null;
    }

    /// <summary>The two cards of a miss that are still up, so they can be shown as wrong.</summary>
    public bool IsMissCard(Card card) => _miss is { } miss && (miss.A == card || miss.B == card);
}
