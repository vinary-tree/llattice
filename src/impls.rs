use crate::{Bottom, JoinSemilattice, Lattice, MeetSemilattice};
use std::collections::HashSet;
use std::hash::{BuildHasher, Hash};

macro_rules! impl_integer_lattice {
    ($($integer:ty),+ $(,)?) => {
        $(
            impl JoinSemilattice for $integer {
                #[inline]
                fn join_assign(&mut self, other: &Self) -> bool {
                    if *self < *other {
                        *self = *other;
                        true
                    } else {
                        false
                    }
                }

                #[inline]
                fn join(&self, other: &Self) -> Self {
                    (*self).max(*other)
                }

                #[inline]
                fn leq(&self, other: &Self) -> bool {
                    self <= other
                }
            }

            impl MeetSemilattice for $integer {
                #[inline]
                fn meet(&self, other: &Self) -> Self {
                    (*self).min(*other)
                }
            }

            impl Lattice for $integer {}

            impl Bottom for $integer {
                #[inline]
                fn bottom() -> Self {
                    <$integer>::MIN
                }
            }
        )+
    };
}

impl_integer_lattice!(u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize);

impl JoinSemilattice for bool {
    #[inline]
    fn join_assign(&mut self, other: &Self) -> bool {
        let changed = !*self && *other;
        *self |= *other;
        changed
    }

    #[inline]
    fn join(&self, other: &Self) -> Self {
        *self || *other
    }

    #[inline]
    fn leq(&self, other: &Self) -> bool {
        !*self || *other
    }
}

impl MeetSemilattice for bool {
    #[inline]
    fn meet(&self, other: &Self) -> Self {
        *self && *other
    }
}

impl Lattice for bool {}

impl Bottom for bool {
    #[inline]
    fn bottom() -> Self {
        false
    }
}

impl<T> JoinSemilattice for Option<T>
where
    T: JoinSemilattice,
{
    #[inline]
    fn join_assign(&mut self, other: &Self) -> bool {
        match (&mut *self, other) {
            (Some(current), Some(incoming)) => current.join_assign(incoming),
            (None, Some(incoming)) => {
                *self = Some(incoming.clone());
                true
            }
            (Some(_), None) | (None, None) => false,
        }
    }

    #[inline]
    fn join(&self, other: &Self) -> Self {
        match (self, other) {
            (Some(left), Some(right)) => Some(left.join(right)),
            (Some(value), None) | (None, Some(value)) => Some(value.clone()),
            (None, None) => None,
        }
    }

    #[inline]
    fn leq(&self, other: &Self) -> bool {
        match (self, other) {
            (None, _) => true,
            (Some(_), None) => false,
            (Some(left), Some(right)) => left.leq(right),
        }
    }
}

impl<T> MeetSemilattice for Option<T>
where
    T: MeetSemilattice,
{
    #[inline]
    fn meet(&self, other: &Self) -> Self {
        match (self, other) {
            (Some(left), Some(right)) => Some(left.meet(right)),
            _ => None,
        }
    }
}

impl<T> Lattice for Option<T> where T: Lattice {}

impl<T> Bottom for Option<T>
where
    T: JoinSemilattice,
{
    #[inline]
    fn bottom() -> Self {
        None
    }
}

impl<T, S> JoinSemilattice for HashSet<T, S>
where
    T: Clone + Eq + Hash,
    S: BuildHasher + Clone,
{
    #[inline]
    fn join_assign(&mut self, other: &Self) -> bool {
        let previous_len = self.len();
        self.extend(other.iter().cloned());
        self.len() != previous_len
    }

    #[inline]
    fn join(&self, other: &Self) -> Self {
        let (larger, smaller) = if self.len() >= other.len() {
            (self, other)
        } else {
            (other, self)
        };
        let mut result = larger.clone();
        result.extend(smaller.iter().cloned());
        result
    }

    #[inline]
    fn leq(&self, other: &Self) -> bool {
        self.is_subset(other)
    }
}

impl<T, S> MeetSemilattice for HashSet<T, S>
where
    T: Clone + Eq + Hash,
    S: BuildHasher + Clone,
{
    #[inline]
    fn meet(&self, other: &Self) -> Self {
        let (smaller, larger) = if self.len() <= other.len() {
            (self, other)
        } else {
            (other, self)
        };
        let mut result = HashSet::with_capacity_and_hasher(smaller.len(), smaller.hasher().clone());
        result.extend(
            smaller
                .iter()
                .filter(|value| larger.contains(*value))
                .cloned(),
        );
        result
    }
}

impl<T, S> Lattice for HashSet<T, S>
where
    T: Clone + Eq + Hash,
    S: BuildHasher + Clone,
{
}

impl<T, S> Bottom for HashSet<T, S>
where
    T: Clone + Eq + Hash,
    S: BuildHasher + Clone + Default,
{
    #[inline]
    fn bottom() -> Self {
        HashSet::with_hasher(S::default())
    }
}
